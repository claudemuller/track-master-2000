package tm2000

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:os"
import rl "vendor:raylib"

NUM_TILES_IN_ROW :: 30
NUM_TILES_IN_COL :: 17

SCALE :: 2
SRC_TILE_SIZE :: 32
TILE_SIZE :: SRC_TILE_SIZE * SCALE

WINDOW_WIDTH :: (NUM_TILES_IN_ROW * TILE_SIZE) + (UI_BORDER_TILE_SIZE * 2) + (WIN_PADDING * 2)
WINDOW_HEIGHT ::
	(NUM_TILES_IN_COL * TILE_SIZE) +
	(UI_TILE_SIZE + UI_BOTTOM_BORDER_TILE_SIZE) +
	(WIN_PADDING * 2)
WIN_PADDING :: 20
CAMERA_SHAKE_MAGNITUDE :: 5.0
CAMERA_SHAKE_DURATION :: 15

DOZE_311_BG_COLOUR :: rl.Color{0, 128, 127, 25}
NUM_GRASS_TILES :: 4

LEVEL_TIME_LIMIT :: 5 // Seconds
BOOT_TIME :: 10 // Seconds

GameMemory :: struct {
	selected_tile: Tile,
	state:         [2]GameState,
}

game_mem: GameMemory
input: Input
camera_shake_duration: f32
level_end: Timer
booting: Timer
booting_sound: rl.Sound
memctr: f64
bg_win: Window

grid: Grid
path: [][2]i32
path_tiles: [dynamic]Tile
proposed_path: [dynamic]Tile

tileset: rl.Texture2D
grass_tileset: rl.Texture2D
station: rl.Texture2D
town: rl.Texture2D
dxtrs: rl.Texture2D

tile_x_offset: i32 = UI_BORDER_TILE_SIZE + WIN_PADDING
tile_y_offset: i32 = UI_TILE_SIZE + WIN_PADDING

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		// for _, entry in track.allocation_map {
		// 	fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
		// }
		// for entry in track.bad_free_array {
		// 	fmt.eprintf("%v bad free\n", entry.location)
		// }
		mem.tracking_allocator_destroy(&track)
	}

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Track Master 2000")
	defer rl.CloseWindow()
	rl.SetTargetFPS(500)
	rl.SetExitKey(.ESCAPE)

	setup()

	for !rl.WindowShouldClose() {
		if game_get_state() == .EXIT {
			break
		}
		input_process(&input)
		update()
		render()
	}
}

setup :: proc() {
	rl.InitAudioDevice()

	booting_sound = rl.LoadSound("res/pc-boot.mp3")

	game_mem = {
		selected_tile = {pos_px = {1, 1, 1, 1}},
	}

	bg_win = ui_new_window(
		"mainwin",
		"Track Master 2000",
		rl.Rectangle {
			20,
			20,
			f32(rl.GetScreenWidth()) - WIN_PADDING * 2,
			f32(rl.GetScreenHeight()) - WIN_PADDING * 2,
		},
		"",
		[]Button{},
		0,
		UI_BG_GRAY,
	)
	bg_win.ctrl_buttons.close.on_click = proc() {
		fmt.println("exting")
		game_push_state(.EXIT)
	}

	tot_num_tiles := NUM_TILES_IN_ROW * NUM_TILES_IN_COL
	grid = {
		pos_px = {
			x = f32(tile_x_offset),
			y = f32(tile_y_offset),
			width = f32(NUM_TILES_IN_ROW * TILE_SIZE),
			height = f32(NUM_TILES_IN_COL * TILE_SIZE),
		},
		tiles = make(map[u16]Tile, tot_num_tiles),
	}

	// Create the grid of tiles
	for y in 0 ..< i32(NUM_TILES_IN_COL) {
		for x in 0 ..< i32(NUM_TILES_IN_ROW) {
			hash := gen_hash(x, y)

			chance := rand.choice([]bool{true, false, false})
			n := rand.int31_max(NUM_GRASS_TILES / 2)
			if chance {
				n += 1
			}

			src_px := rl.Rectangle {
				x      = f32(SRC_TILE_SIZE * n),
				width  = SRC_TILE_SIZE,
				height = SRC_TILE_SIZE,
			}

			grid.tiles[hash] = Tile {
				pos_grid = {f32(x), f32(y)},
				pos_px = rl.Rectangle {
					x = f32(x) * TILE_SIZE + f32(tile_x_offset),
					y = f32(y) * TILE_SIZE + f32(tile_y_offset),
					width = TILE_SIZE,
					height = TILE_SIZE,
				},
				src_px = src_px,
				type = .GRASS,
			}
		}
	}

	station_tile := &grid.tiles[0]
	station_tile.type = .STATION

	ts: [4][4]rl.Rectangle
	ts[int(Direction.RIGHT)][int(Direction.RIGHT)] = {0, 0, SRC_TILE_SIZE, SRC_TILE_SIZE}
	ts[int(Direction.RIGHT)][int(Direction.UP)] = {
		3 * SRC_TILE_SIZE,
		0,
		SRC_TILE_SIZE,
		SRC_TILE_SIZE,
	}
	ts[int(Direction.RIGHT)][int(Direction.DOWN)] = {
		2 * SRC_TILE_SIZE,
		1 * SRC_TILE_SIZE,
		SRC_TILE_SIZE,
		SRC_TILE_SIZE,
	}
	ts[int(Direction.LEFT)][int(Direction.LEFT)] = {0, 0, SRC_TILE_SIZE, SRC_TILE_SIZE}
	ts[int(Direction.LEFT)][int(Direction.UP)] = {
		1 * SRC_TILE_SIZE,
		1 * SRC_TILE_SIZE,
		SRC_TILE_SIZE,
		SRC_TILE_SIZE,
	}
	ts[int(Direction.LEFT)][int(Direction.DOWN)] = {
		0,
		1 * SRC_TILE_SIZE,
		SRC_TILE_SIZE,
		SRC_TILE_SIZE,
	}
	ts[int(Direction.UP)][int(Direction.LEFT)] = {
		2 * SRC_TILE_SIZE,
		1 * SRC_TILE_SIZE,
		SRC_TILE_SIZE,
		SRC_TILE_SIZE,
	}
	ts[int(Direction.UP)][int(Direction.UP)] = {1 * SRC_TILE_SIZE, 0, SRC_TILE_SIZE, SRC_TILE_SIZE}
	ts[int(Direction.UP)][int(Direction.RIGHT)] = {
		0,
		1 * SRC_TILE_SIZE,
		SRC_TILE_SIZE,
		SRC_TILE_SIZE,
	}
	ts[int(Direction.DOWN)][int(Direction.LEFT)] = {
		3 * SRC_TILE_SIZE,
		0,
		SRC_TILE_SIZE,
		SRC_TILE_SIZE,
	}
	ts[int(Direction.DOWN)][int(Direction.DOWN)] = {
		1 * SRC_TILE_SIZE,
		0,
		SRC_TILE_SIZE,
		SRC_TILE_SIZE,
	}
	ts[int(Direction.DOWN)][int(Direction.RIGHT)] = {
		1 * SRC_TILE_SIZE,
		1 * SRC_TILE_SIZE,
		SRC_TILE_SIZE,
		SRC_TILE_SIZE,
	}

	path_len: i32 = 100
	path = gen_path({0, 1}, path_len, NUM_TILES_IN_ROW, NUM_TILES_IN_COL)
	src_px := rl.Rectangle{0, 0, SRC_TILE_SIZE, SRC_TILE_SIZE}

	hash: u16
	for i in 0 ..< len(path) {
		this_tile := path[i]

		// Lookup first tile
		if i == 0 {
			prev := path[i + 1]
			next := path[i + 1]
			off_tile_dir := next - this_tile
			if off_tile_dir == {0, 1} {
				src_px = ts[Direction.DOWN][Direction.DOWN]
			} else if off_tile_dir == {1, 0} {
				src_px = ts[Direction.RIGHT][Direction.RIGHT]
			}
		}

		// Lookup the middle tiles
		if i > 0 && i < len(path) - 1 {
			prev := path[i - 1]
			next := path[i + 1]
			on_tile_dir_key, off_tile_dir_key := lookup_tile(prev, this_tile, next)
			src_px = ts[on_tile_dir_key][off_tile_dir_key]
		}

		// Lookup last tile
		if i == len(path) - 1 {
			prev := path[i - 1]
			next := [2]i32{1, 0}
			on_tile_dir_key, off_tile_dir_key := lookup_tile(prev, this_tile, next)
			src_px = ts[on_tile_dir_key][off_tile_dir_key]
		}

		hash = gen_hash(this_tile.x, this_tile.y)
		t := Tile {
			pos_grid = {f32(this_tile.x), f32(this_tile.y)},
			pos_px   = {
				f32(this_tile.x * TILE_SIZE + tile_x_offset),
				f32(this_tile.y * TILE_SIZE + tile_y_offset),
				TILE_SIZE,
				TILE_SIZE,
			},
			src_px   = src_px,
			type     = .TRACK,
		}
		// grid.tiles[hash] = t
		append(&path_tiles, t)
	}

	town_tile := &grid.tiles[hash]
	town_tile.type = .TOWN

	tileset = rl.LoadTexture("res/tileset.png")
	grass_tileset = rl.LoadTexture("res/grass-tileset.png")
	station = rl.LoadTexture("res/station.png")
	town = rl.LoadTexture("res/town.png")
	dxtrs = rl.LoadTexture("res/dxtrs-games-vin.png")

	ui_setup()

	boot_game()
}

update :: proc() {
	if game_get_state() == .BOOTING {
		if timer_done(booting) {
			game_push_state(.MAIN_MENU)
		}
		return
	}

	// TODO:(lukefilewalker) everything else won't get updated if the ui consumes input :(
	if ui_update() do return

	if .LEFT in input.mouse.btns {
		if rl.CheckCollisionPointRec(input.mouse.pos_px, bg_win.ctrl_buttons.close.pos_px) {
			if bg_win.ctrl_buttons.close.on_click != nil {
				bg_win.ctrl_buttons.close.on_click()
			}
		}
	}

	switch game_get_state() {
	case .BOOTING:

	case .MAIN_MENU:

	case .PLAYING:
		if game_get_prev_state() == .MAIN_MENU {
			start_timer(&level_end, LEVEL_TIME_LIMIT)
			game_push_state(.PLAYING)
		}

		update_grid()

		// if camera_shake_duration > 0 {
		// 	camera.offset.x = f32(
		// 		rl.GetRandomValue(-CAMERA_SHAKE_MAGNITUDE, CAMERA_SHAKE_MAGNITUDE),
		// 	)
		// 	camera.offset.y = f32(
		// 		rl.GetRandomValue(-CAMERA_SHAKE_MAGNITUDE, CAMERA_SHAKE_MAGNITUDE),
		// 	)
		// 	camera_shake_duration -= 1
		// } else {
		// 	camera.offset = {0, 0}
		// }

		// Level time is up, check path
		if timer_done(level_end) {
			check_path(path_tiles, proposed_path)
		}
	case .SIMULATING:
		check_path(path_tiles, proposed_path)

	// if camera_shake_duration > 0 {
	// 	camera.offset.x = f32(
	// 		rl.GetRandomValue(-CAMERA_SHAKE_MAGNITUDE, CAMERA_SHAKE_MAGNITUDE),
	// 	)
	// 	camera.offset.y = f32(
	// 		rl.GetRandomValue(-CAMERA_SHAKE_MAGNITUDE, CAMERA_SHAKE_MAGNITUDE),
	// 	)
	// 	camera_shake_duration -= 1
	// } else {
	// 	camera.offset = {0, 0}
	// }
	case .WIN:
		w_win_width: f32 = 500
		w_win_rec := rl.Rectangle {
			x      = f32(rl.GetScreenWidth() / 2) - w_win_width / 2 - WIN_PADDING * 2,
			y      = f32(300 + WIN_PADDING * 1.5),
			height = 300 + UI_BOTTOM_BORDER_TILE_SIZE + UI_TILE_SIZE + UI_HORIZONTAL_RULE_SIZE + UI_BUTTON_SIZE,
			width  = w_win_width,
		}
		w_btns := []Button{}
		w_txt := fmt.ctprint("You win :)")
		w_win := ui_new_window(
			"winwin",
			"Win",
			w_win_rec,
			w_txt,
			w_btns,
			UI_WINDOW_PADDING,
			UI_BG_GRAY,
		)
		w_win.ctrl_buttons.close.on_click = proc() {
			game_push_state(.EXIT)
		}

		append(&windows, w_win)

	case .GAME_OVER:
		go_win_width: f32 = 500
		go_win_rec := rl.Rectangle {
			x      = f32(rl.GetScreenWidth() / 2) - go_win_width / 2 - WIN_PADDING * 2,
			y      = f32(300 + WIN_PADDING * 1.5),
			height = 300 + UI_BOTTOM_BORDER_TILE_SIZE + UI_TILE_SIZE + UI_HORIZONTAL_RULE_SIZE + UI_BUTTON_SIZE,
			width  = go_win_width,
		}
		go_btns := []Button{}
		go_txt := fmt.ctprint("Everyone died :(")
		go_win := ui_new_window(
			"gameoverwin",
			"Death to all",
			go_win_rec,
			go_txt,
			go_btns,
			UI_WINDOW_PADDING,
			UI_BG_GRAY,
		)
		go_win.ctrl_buttons.close.on_click = proc() {
			game_push_state(.EXIT)
		}

		append(&windows, go_win)

	case .EXIT:
	}
}

render :: proc() {
	rl.BeginDrawing()

	if game_get_state() == .BOOTING {
		draw_boot_screen()
	} else {
		rl.ClearBackground(DOZE_311_BG_COLOUR)

		// Draw main UI window
		ui_draw_window(bg_win)

		src: rl.Rectangle
		for _, t in grid.tiles {
			switch t.type {
			case .TRACK:
				// rl.DrawRectangleRec(t.pos_px, rl.GRAY)
				rl.DrawTexturePro(tileset, t.src_px, t.pos_px, {0, 0}, 0, rl.WHITE)
			// rl.DrawRectangleLinesEx(t.pos_px, 1, t.colour)

			case .GRASS:
				rl.DrawTexturePro(grass_tileset, t.src_px, t.pos_px, {0, 0}, 0, rl.WHITE)

			case .STATION:
				rl.DrawTexturePro(
					station,
					{0, 0, SRC_TILE_SIZE, SRC_TILE_SIZE},
					t.pos_px,
					{0, 0},
					0,
					rl.WHITE,
				)

			case .TOWN:
				rl.DrawTexturePro(
					town,
					{0, 0, SRC_TILE_SIZE, SRC_TILE_SIZE},
					t.pos_px,
					{0, 0},
					0,
					rl.WHITE,
				)

			case .NONE:
			}
		}

		// draw_debug_ui()

		ui_draw()
	}

	rl.EndDrawing()
}

boot_game :: proc() {
	memctr = rl.GetTime()
	rl.PlaySound(booting_sound)
	start_timer(&booting, BOOT_TIME)
	game_push_state(.BOOTING)
}

draw_boot_screen :: proc() {
	rl.ClearBackground(rl.BLACK)

	font_size: i32 = 20
	txt_colour := rl.Color{170, 170, 170, 255}
	top_txt := `Dxtrs T-1000 Modular BIOS v1.1, An Awesome Game Company
Copyright (C) 2020-25, Dxtrs Games, Inc.

%s


80486DX2 CPU at 66Mhz
Memory Test: %d KB`


	date_str := "10/01/2025"
	memctr = rl.GetTime() * 1000 - memctr

	rl.DrawText(
		fmt.ctprintf(top_txt, date_str, i32(memctr)),
		WIN_PADDING * 2,
		WIN_PADDING * 2,
		font_size,
		txt_colour,
	)

	bottom_txt := "Press DEL to enter SETUP\n%s-SYS-2401-A/C/2B"
	rl.DrawText(
		fmt.ctprintf(bottom_txt, date_str),
		WIN_PADDING * 2,
		rl.GetScreenHeight() - WIN_PADDING * 2 - font_size * 2,
		font_size,
		txt_colour,
	)

	rl.DrawTexture(
		dxtrs,
		rl.GetScreenWidth() - dxtrs.width - WIN_PADDING * 2,
		WIN_PADDING * 2,
		rl.WHITE,
	)
}

update_grid :: proc() {
	if !rl.CheckCollisionPointRec(input.mouse.pos_px, grid.pos_px) {
		return
	}

	if .LEFT in input.mouse.btns {
		if game_mem.selected_tile.type != .NONE {
			x, y := get_mouse_grid_pos()
			hash := gen_hash(x, y)

			t := &grid.tiles[hash]
			t.src_px.x = game_mem.selected_tile.src_px.x
			t.src_px.y = game_mem.selected_tile.src_px.y
			t.pos_px.x = f32(x * TILE_SIZE + tile_x_offset)
			t.pos_px.y = f32(y * TILE_SIZE + tile_y_offset)
			t.type = game_mem.selected_tile.type

			append(
				&proposed_path,
				Tile {
					pos_grid = {f32(x), f32(y)},
					src_px = t.src_px,
					type = game_mem.selected_tile.type,
				},
			)

			// Remove tile from available tiles
			tile_nums[hash] -= 1
		}
	}

	if .RIGHT in input.mouse.btns {
		if game_mem.selected_tile.type != .NONE {
			x, y := get_mouse_grid_pos()
			hash := gen_hash(x, y)

			t := &grid.tiles[hash]
			t.type = .GRASS

			// Put tile back into available tiles
			tile_nums[hash] += 1
		}
	}
}

draw_debug_ui :: proc() {
	rl.DrawText(fmt.ctprintf("%s", game_mem.state), 10, 10, 20, rl.BLACK)

	i := 0
	for t in path {
		x := t.x * TILE_SIZE + tile_x_offset
		y := t.y * TILE_SIZE + tile_y_offset
		rl.DrawRectangleLines(x, y, TILE_SIZE, TILE_SIZE, rl.PINK)
		rl.DrawText(fmt.ctprint(i), x, y, 25, rl.BLACK)
		i += 1
	}
}

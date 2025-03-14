package tm2000

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:os"
// import "core:os"
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

LEVEL_TIME_LIMIT :: 30 // Seconds

Tile :: struct {
	pos_grid: rl.Vector2,
	pos_px:   rl.Rectangle,
	src_px:   rl.Rectangle,
	type:     TileType,
}

Grid :: struct {
	pos_px: rl.Rectangle,
	tiles:  map[u16]Tile,
}

TileType :: enum {
	NONE, // 0
	GRASS,
	TRACK,
	STATION,
	TOWN,
}

GameState :: enum {
	MAIN_MENU,
	PLAYING,
	SIMULATING,
	WIN,
	GAME_OVER,
	EXIT,
}

GameMemory :: struct {
	selected_tile: Tile,
	state:         GameState,
}

game_mem: GameMemory
input: Input
camera_shake_duration: f32
level_end: Timer

grid: Grid
path: [][2]i32
path_tiles: [dynamic]Tile
proposed_path: [dynamic]Tile

tileset: rl.Texture2D
grass_tileset: rl.Texture2D
station: rl.Texture2D
town: rl.Texture2D
bg_win: Window

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
		if game_mem.state == .EXIT {
			break
		}
		input_process(&input)
		update()
		render()
	}
}

setup :: proc() {
	game_mem = {
		selected_tile = {pos_px = {1, 1, 1, 1}},
		state = .MAIN_MENU,
	}

	bg_win = ui_new_window(
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
		game_mem.state = .EXIT
		fmt.println("exting")
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

	ui_setup()
}

update :: proc() {
	// TODO:(lukefilewalker) everything else won't get updated if the ui consumes input :(
	if ui_update() do return

	switch game_mem.state {
	case .MAIN_MENU:
		// if play is pressed
		start_timer(&level_end, LEVEL_TIME_LIMIT)

	case .PLAYING:
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
	// Show winning screen

	case .GAME_OVER:
	// Show game over screen

	case .EXIT:
	}
}

render :: proc() {
	rl.BeginDrawing()
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

	rl.EndDrawing()
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

check_path :: proc(path: [dynamic]Tile, proposed_path: [dynamic]Tile) {
	for i in 0 ..< len(proposed_path) - 1 {
		if proposed_path[i].pos_grid != path[i].pos_grid ||
		   proposed_path[i].src_px != path[i].src_px ||
		   proposed_path[i].type != path[i].type {
			game_mem.state = .GAME_OVER
			camera_shake_duration = CAMERA_SHAKE_DURATION
		}
	}
	game_mem.state = .WIN
}

lookup_tile :: proc(prev, this_tile, next: [2]i32) -> (Direction, Direction) {
	on_tile_dir := this_tile - prev
	off_tile_dir := next - this_tile

	on_tile_dir_key: Direction
	if on_tile_dir == {1, 0} || on_tile_dir == {2, 0} {
		on_tile_dir_key = .RIGHT
	} else if on_tile_dir == {-1, 0} || on_tile_dir == {-2, 0} {
		on_tile_dir_key = .LEFT
	} else if on_tile_dir == {0, 1} || on_tile_dir == {0, 2} {
		on_tile_dir_key = .DOWN
	} else if on_tile_dir == {0, -1} || on_tile_dir == {0, -2} {
		on_tile_dir_key = .UP
	}

	off_tile_dir_key: Direction
	if off_tile_dir == {1, 0} || off_tile_dir == {2, 0} {
		off_tile_dir_key = .RIGHT
	} else if off_tile_dir == {-1, 0} || off_tile_dir == {-2, 0} {
		off_tile_dir_key = .LEFT
	} else if off_tile_dir == {0, 1} || off_tile_dir == {0, 2} {
		off_tile_dir_key = .DOWN
	} else if off_tile_dir == {0, -1} || off_tile_dir == {0, -2} {
		off_tile_dir_key = .UP
	}

	return on_tile_dir_key, off_tile_dir_key
}

get_mouse_grid_pos :: proc() -> (i32, i32) {
	x := math.floor_f32(f32(i32(input.mouse.pos_px.x) - tile_x_offset) / TILE_SIZE)
	y := math.floor_f32(f32(i32(input.mouse.pos_px.y) - tile_y_offset) / TILE_SIZE)
	return i32(x), i32(y)
}

gen_hash :: proc(x, y: i32) -> u16 {
	return u16(((x * 73856093) + (y * 19349663)) % 65536)
}

draw_debug_ui :: proc() {
	rl.DrawText(fmt.ctprintf("%v", get_elapsed(level_end)), 10, 10, 20, rl.BLACK)

	i := 0
	for t in path {
		x := t.x * TILE_SIZE + tile_x_offset
		y := t.y * TILE_SIZE + tile_y_offset
		rl.DrawRectangleLines(x, y, TILE_SIZE, TILE_SIZE, rl.PINK)
		rl.DrawText(fmt.ctprint(i), x, y, 25, rl.BLACK)
		i += 1
	}
}

package pathways

import "core:fmt"
import "core:math/rand"
import "core:mem"
// import "core:os"
import rl "vendor:raylib"

NUM_TILES_IN_ROW :: 30
NUM_TILES_IN_COL :: 17

SCALE :: 2
SRC_TILE_SIZE :: 32
TILE_SIZE :: SRC_TILE_SIZE * SCALE

WINDOW_WIDTH :: NUM_TILES_IN_ROW * TILE_SIZE + UI_BORDER_TILE_SIZE * 2
WINDOW_HEIGHT :: NUM_TILES_IN_COL * TILE_SIZE + UI_TILE_SIZE + UI_BOTTOM_BORDER_TILE_SIZE
WIN_PADDING :: 20

DOZE_311_BG_COLOUR :: rl.Color{0, 128, 127, 25}

NUM_GRASS_TILES :: 4

Tile :: struct {
	pos_grid: []i32,
	pos_px:   rl.Rectangle,
	src_px:   rl.Rectangle,
	type:     TileType,
}

Grid :: struct {
	pos_px: rl.Rectangle,
	tiles:  map[u16]Tile,
}

TileType :: enum {
	GRASS, // 0
	TRACK,
}

input: Input
grid: Grid
path: [][2]i32
tileset: rl.Texture2D
grass_tileset: rl.Texture2D
tile_x_offset: i32 = UI_BORDER_TILE_SIZE + WIN_PADDING
tile_y_offset: i32 = UI_TILE_SIZE + WIN_PADDING

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		for _, entry in track.allocation_map {
			fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
		}
		for entry in track.bad_free_array {
			fmt.eprintf("%v bad free\n", entry.location)
		}
		mem.tracking_allocator_destroy(&track)
	}

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Pathways")
	defer rl.CloseWindow()
	rl.SetTargetFPS(500)
	rl.SetExitKey(.ESCAPE)

	setup()

	for !rl.WindowShouldClose() {
		input_process(&input)
		update()
		render()
	}
}

setup :: proc() {
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

	for y in 0 ..< i32(NUM_TILES_IN_COL) {
		for x in 0 ..< i32(NUM_TILES_IN_ROW) {
			hash := gen_hash(x, y)
			n := rand.int31_max(NUM_GRASS_TILES)
			src_px := rl.Rectangle {
				x      = f32(TILE_SIZE * n),
				width  = TILE_SIZE,
				height = TILE_SIZE,
			}

			grid.tiles[hash] = Tile {
				pos_grid = {x, y},
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

	path = gen_path({0, 0}, 30, NUM_TILES_IN_ROW, NUM_TILES_IN_COL)
	src_px := rl.Rectangle{0, 0, SRC_TILE_SIZE, SRC_TILE_SIZE}

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
			// TODO:(lukefilewalker) this will be the village location
			next := [2]i32{1, 0}
			on_tile_dir_key, off_tile_dir_key := lookup_tile(prev, this_tile, next)
			src_px = ts[on_tile_dir_key][off_tile_dir_key]
		}

		hash := gen_hash(this_tile.x, this_tile.y)
		grid.tiles[hash] = Tile {
			pos_grid = {this_tile.x, this_tile.y},
			pos_px   = {
				f32(this_tile.x * TILE_SIZE + tile_x_offset),
				f32(this_tile.y * TILE_SIZE + tile_y_offset),
				TILE_SIZE,
				TILE_SIZE,
			},
			src_px   = src_px,
			type     = .TRACK,
		}
	}

	tileset = rl.LoadTexture("res/tileset.png")
	grass_tileset = rl.LoadTexture("res/grass-tileset.png")

	ui_setup()

	// fmt.printfln("%v", path)
	// os.exit(0)
}

update :: proc() {
	if ui_update() do return

	update_grid()
}

render :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(DOZE_311_BG_COLOUR)

	// Draw main UI window
	ui_draw_window(
		rl.Rectangle {
			20,
			20,
			f32(rl.GetScreenWidth()) - WIN_PADDING * 2,
			f32(rl.GetScreenHeight()) - WIN_PADDING * 2,
		},
		"Track Master 2000",
		UI_BG_GRAY,
	)

	src: rl.Rectangle
	for _, t in grid.tiles {
		switch t.type {
		case .TRACK:
			// rl.DrawRectangleRec(t.pos_px, rl.GRAY)
			rl.DrawTexturePro(tileset, t.src_px, t.pos_px, {0, 0}, 0, rl.WHITE)
		// rl.DrawRectangleLinesEx(t.pos_px, 1, t.colour)

		case .GRASS:
			rl.DrawTexturePro(grass_tileset, t.src_px, t.pos_px, {0, 0}, 0, rl.WHITE)
		}
	}

	ui_draw()
	// draw_debug_ui()

	rl.EndDrawing()
}

update_grid :: proc() {
	if !rl.CheckCollisionPointRec(input.mouse.pos_px, grid.pos_px) {
		return
	}

	if .LEFT in input.mouse.btns {
		x, y := get_mouse_grid_pos()
		hash := gen_hash(x, y)

		t := &grid.tiles[hash]
	}
}

draw_debug_ui :: proc() {
	rl.DrawRectangleLinesEx(grid.pos_px, 1, rl.BLACK)
	x, y := get_mouse_grid_pos()
	rl.DrawText(
		fmt.ctprintf("%v [%v] %v [%v]", x, NUM_TILES_IN_ROW, y, NUM_TILES_IN_COL),
		10,
		10,
		20,
		rl.BLACK,
	)

	i := 0
	for t in path {
		x := t.x * TILE_SIZE + tile_x_offset
		y := t.y * TILE_SIZE + tile_y_offset
		rl.DrawRectangleLines(x, y, TILE_SIZE, TILE_SIZE, rl.PINK)
		rl.DrawText(fmt.ctprint(i), x, y, 25, rl.BLACK)
		i += 1
	}
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
	x := (i32(input.mouse.pos_px.x) - tile_x_offset) / TILE_SIZE
	y := (i32(input.mouse.pos_px.y) - tile_y_offset) / TILE_SIZE
	return x, y
}

gen_hash :: proc(x, y: i32) -> u16 {
	return u16(((x * 73856093) + (y * 19349663)) % 65536)
}

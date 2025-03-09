package pathways

import "core:fmt"
import "core:mem"
// import "core:os"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1920
WINDOW_HEIGHT :: 1088
NUM_TILES_IN_WIN_ROW :: 30
NUM_TILES_IN_WIN_COL :: 17

SCALE :: 2
SRC_TILE_SIZE :: 32
TILE_SIZE :: SRC_TILE_SIZE * SCALE
TILE_TOP_OFFSET :: 1
TILE_BOTTOM_OFFSET :: 1
TILE_LEFT_OFFSET :: 1
TILE_RIGHT_OFFSET :: 1
NUM_TILES_IN_ROW: i32 : NUM_TILES_IN_WIN_ROW - TILE_LEFT_OFFSET - TILE_RIGHT_OFFSET
NUM_TILES_IN_COL: i32 : NUM_TILES_IN_WIN_COL - TILE_TOP_OFFSET - TILE_BOTTOM_OFFSET

Tile :: struct {
	pos_grid: []i32,
	pos_px:   rl.Rectangle,
	src_px:   rl.Rectangle,
	colour:   rl.Color,
}

Grid :: struct {
	pos_px: rl.Rectangle,
	tiles:  map[u16]Tile,
}

TileType :: enum {
	HORIZONTAL,
	VERTICAL,
	CROSSING,
	RIGHT_TO_UP,
	RIGHT_TO_DOWN,
	LEFT_TO_UP,
	LEFT_TO_DOWN,
	UP_TO_RIGHT,
	UP_TO_LEFT,
	DOWN_TO_RIGHT,
	DOWN_TO_LEFT,
}

input: Input
grid: Grid
path: [][2]i32
tileset: rl.Texture2D
tiles: map[TileType]rl.Rectangle

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

	window_width: i32 = NUM_TILES_IN_WIN_ROW * TILE_SIZE
	window_height: i32 = NUM_TILES_IN_WIN_COL * TILE_SIZE

	rl.InitWindow(window_width, window_height, "Pathways")
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
	tile_x_offset: f32 = TILE_LEFT_OFFSET * TILE_SIZE
	tile_y_offset: f32 = TILE_TOP_OFFSET * TILE_SIZE
	grid = {
		pos_px = {
			x = tile_x_offset,
			y = tile_y_offset,
			width = f32(NUM_TILES_IN_ROW * TILE_SIZE),
			height = f32(NUM_TILES_IN_COL * TILE_SIZE),
		},
		tiles = make(map[u16]Tile, tot_num_tiles),
	}

	for y in 0 ..< NUM_TILES_IN_COL {
		for x in 0 ..< NUM_TILES_IN_ROW {
			hash := gen_hash(x, y)

			grid.tiles[hash] = Tile {
				pos_grid = {x, y},
				pos_px = rl.Rectangle {
					x = f32(x) * TILE_SIZE + tile_x_offset,
					y = f32(y) * TILE_SIZE + tile_y_offset,
					width = TILE_SIZE,
					height = TILE_SIZE,
				},
				colour = rl.GRAY,
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

	fmt.printfln("%v", ts)

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
				f32(this_tile.x) * TILE_SIZE + tile_x_offset,
				f32(this_tile.y) * TILE_SIZE + tile_y_offset,
				TILE_SIZE,
				TILE_SIZE,
			},
			src_px   = src_px,
		}
	}

	tileset = rl.LoadTexture("res/tileset.png")

	// fmt.printfln("%v", path)
	// os.exit(0)
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

update :: proc() {
	update_grid()
	update_ui()
}

update_grid :: proc() {
	if !rl.CheckCollisionPointRec(input.mouse.pos_px, grid.pos_px) {
		return
	}

	if .LEFT in input.mouse.btns {
		x, y := get_mouse_grid_pos()
		hash := gen_hash(x, y)

		t := &grid.tiles[hash]
		t.colour = rl.RED
	}
}

update_ui :: proc() {

}

render :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.LIGHTGRAY)

	src: rl.Rectangle
	for _, t in grid.tiles {
		// rl.DrawRectangleRec(t.pos_px, rl.GRAY)
		rl.DrawTexturePro(tileset, t.src_px, t.pos_px, {0, 0}, 0, rl.WHITE)
		rl.DrawRectangleLinesEx(t.pos_px, 1, t.colour)
	}

	draw_ui()
	draw_debug_ui()

	rl.EndDrawing()
}

draw_ui :: proc() {
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
	tile_x_offset: i32 = TILE_LEFT_OFFSET * TILE_SIZE
	tile_y_offset: i32 = TILE_TOP_OFFSET * TILE_SIZE
	for t in path {
		x := t.x * TILE_SIZE + tile_x_offset
		y := t.y * TILE_SIZE + tile_y_offset
		rl.DrawRectangleLines(x, y, TILE_SIZE, TILE_SIZE, rl.PINK)
		rl.DrawText(fmt.ctprint(i), x, y, 25, rl.BLACK)
		i += 1
	}
}

get_mouse_grid_pos :: proc() -> (i32, i32) {
	tile_x_offset: i32 = TILE_LEFT_OFFSET * TILE_SIZE
	tile_y_offset: i32 = TILE_TOP_OFFSET * TILE_SIZE
	x := (i32(input.mouse.pos_px.x) - tile_x_offset) / TILE_SIZE
	y := (i32(input.mouse.pos_px.y) - tile_y_offset) / TILE_SIZE
	return x, y
}

gen_hash :: proc(x, y: i32) -> u16 {
	return u16(((x * 73856093) + (y * 19349663)) % 65536)
}

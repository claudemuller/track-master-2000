package pathways

import "core:fmt"
import "core:mem"
// import "core:os"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1920
WINDOW_HEIGHT :: 1088
NUM_TILES_IN_WIN_ROW :: 30
NUM_TILES_IN_WIN_COL :: 17

TILE_SIZE :: 64
TILE_TOP_OFFSET :: 1
TILE_BOTTOM_OFFSET :: 1
TILE_LEFT_OFFSET :: 1
TILE_RIGHT_OFFSET :: 1
NUM_TILES_IN_ROW: i32 : NUM_TILES_IN_WIN_ROW - TILE_LEFT_OFFSET - TILE_RIGHT_OFFSET
NUM_TILES_IN_COL: i32 : NUM_TILES_IN_WIN_COL - TILE_TOP_OFFSET - TILE_BOTTOM_OFFSET

Tile :: struct {
	pos_grid: struct {
		x: i32,
		y: i32,
	},
	pos_px:   rl.Rectangle,
	colour:   rl.Color,
}

Grid :: struct {
	pos_px: rl.Rectangle,
	tiles:  map[u16]Tile,
}

input: Input
grid: Grid
path: [][2]i32

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
				pos_grid = {x = x, y = y},
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

	path = gen_path({0, 0}, 6, NUM_TILES_IN_ROW, NUM_TILES_IN_COL)
	for p in path {
		hash := gen_hash(p.x, p.y)
		grid.tiles[hash] = Tile {
			pos_grid = {p.x, p.y},
			pos_px   = {
				f32(p.x) * TILE_SIZE + tile_x_offset,
				f32(p.y) * TILE_SIZE + tile_y_offset,
				TILE_SIZE,
				TILE_SIZE,
			},
		}
	}

	// fmt.printfln("%v", path)
	// os.exit(0)
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

	for _, t in grid.tiles {
		rl.DrawRectangleRec(t.pos_px, rl.GRAY)
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

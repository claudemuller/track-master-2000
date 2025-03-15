package tm2000

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

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

check_path :: proc(path: [dynamic]Tile, p: Tile) -> int {
	for j in 0 ..< len(path) {
		if p.pos_grid == path[j].pos_grid && p.src_px == path[j].src_px && p.type == path[j].type {
			return 1
		}

		// if proposed_path[i].pos_grid != path[i].pos_grid ||
		//    proposed_path[i].src_px != path[i].src_px ||
		//    proposed_path[i].type != path[i].type {
		// fmt.printfln("%v - %v", proposed_path[i].pos_grid, path[i].pos_grid)
		// fmt.printfln("%v - %v", proposed_path[i].src_px, path[i].src_px)
		// fmt.printfln("%v - %v", proposed_path[i].type, path[i].type)
		// fmt.printfln("%v\n%v", proposed_path, path)

		// game_push_state(.GAME_OVER)
		// return
		// }
	}

	// fmt.printfln("%v - %v [%v - %v]", correct_nodes, len(path) - 1, len(proposed_path), len(path))
	// for j in 0 ..< len(path) {
	// 	fmt.printfln("%v", path[j].pos_grid)
	// }
	// fmt.printfln("%v\n%v", proposed_path, path)

	// if correct_nodes == len(path) - 1 {
	// 	game_push_state(.WIN)
	// } else {
	// 	game_push_state(.GAME_OVER)
	// }

	return 0
}

get_mouse_grid_pos :: proc() -> (i32, i32) {
	x := math.floor_f32(f32(i32(input.mouse.pos_px.x) - tile_x_offset) / TILE_SIZE)
	y := math.floor_f32(f32(i32(input.mouse.pos_px.y) - tile_y_offset) / TILE_SIZE)
	return i32(x), i32(y)
}

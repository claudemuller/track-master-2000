package pathways

import "core:fmt"
import "core:math/rand"

Direction :: enum {
	UP,
	RIGHT,
	DOWN,
	LEFT,
}

gen_path :: proc(start_pos: [2]i32, path_len, maxx, maxy: i32) -> [][2]i32 {
	path := make([][2]i32, path_len)
	path[0] = start_pos

	for i in 1 ..< path_len {
		directions := [4][2]i32{{0, -1}, {1, 0}, {0, 1}, {-1, 0}}
		tried_directions: map[Direction][2]i32

		prev_tile := path[i - 1]
		try_dir := rand.choice_enum(Direction)
		tried_directions[try_dir] = directions[try_dir]
		try_pos := prev_tile + directions[try_dir]

		for !is_direction_valid(&path, try_pos, try_dir) {
			try_dir = rand.choice_enum(Direction)
			tried_directions[try_dir] = directions[try_dir]
			try_pos = prev_tile + directions[try_dir]

			if len(tried_directions) == 4 {
				directions = [4][2]i32{{0, -2}, {2, 0}, {0, 2}, {-2, 0}}
			}
		}

		path[i] = try_pos
	}

	return path
}

is_direction_valid :: proc(path: ^[][2]i32, try_pos: [2]i32, try_dir: Direction) -> bool {
	// Check if the position is already in the path
	for p in path {
		if p == try_pos {
			return false
		}
	}

	// Make sure the next position is within the grid
	if try_dir == .UP do return try_pos.y > 0
	if try_dir == .RIGHT do return try_pos.x < NUM_TILES_IN_ROW
	if try_dir == .DOWN do return try_pos.y < NUM_TILES_IN_COL
	if try_dir == .LEFT do return try_pos.x > 0

	return true
}

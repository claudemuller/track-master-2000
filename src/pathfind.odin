package pathways

import "core:fmt"
import "core:math/rand"

Direction :: enum {
	UP,
	RIGHT,
	DOWN,
	LEFT,
}
directions := [4][2]i32{{0, -1}, {1, 0}, {0, 1}, {-1, 0}}

gen_path :: proc(start_pos: [2]i32, path_len, maxx, maxy: i32) -> [][2]i32 {
	path := make([][2]i32, path_len)
	path[0] = start_pos

	for i in 1 ..< path_len {
		prev_tile := path[i - 1]
		try_dir := rand.choice_enum(Direction)
		try_pos := prev_tile + directions[try_dir]

		// TODO:(lukefilewalker) pop the random choice off a list instead to avoid repeat guesses
		// of a choice that won't work
		for !is_direction_valid(&path, try_pos, try_dir) {
			try_dir = rand.choice_enum(Direction)
			try_pos = prev_tile + directions[try_dir]
		}

		path[i] = try_pos
	}

	fmt.printfln("path:%v\n", path)

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

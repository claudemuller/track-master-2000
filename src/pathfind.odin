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
	path = make([][2]i32, path_len)
	path[0] = start_pos

	for i in 1 ..< path_len {
		prev_tile := path[i - 1]
		try_dir := rand.choice_enum(Direction)

		for !check_direction(prev_tile, try_dir) {
			// TODO:(lukefilewalker) not nice :(
			try_dir = rand.choice_enum(Direction)

			fmt.printfln("%v %v", try_dir, prev_tile)

			switch try_dir {
			case .UP:
				path[i] = {prev_tile.x, prev_tile.y - 1}

			case .RIGHT:
				path[i] = {prev_tile.x + 1, prev_tile.y}

			case .DOWN:
				path[i] = {prev_tile.x, prev_tile.y + 1}

			case .LEFT:
				path[i] = {prev_tile.x - 1, prev_tile.y}
			}
		}
	}

	return path
}

check_direction :: proc(prev: [2]i32, try_dir: Direction) -> bool {
	switch try_dir {
	case .UP:
		new_y := prev.y - 1
		return new_y > 0 && new_y != prev.y

	case .RIGHT:
		new_x := prev.x + 1
		return new_x < NUM_TILES_IN_ROW && new_x != prev.x

	case .DOWN:
		new_y := prev.y + 1
		return new_y < NUM_TILES_IN_COL && new_y != prev.y

	case .LEFT:
		new_x := prev.x - 1
		return new_x > 0 && new_x != prev.x
	}
	return false
}

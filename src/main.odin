package pathways

import rl "vendor:raylib"

WINDOW_WIDTH :: 1920
WINDOW_HEIGHT :: 1080

input: Input

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Pathways")
	defer rl.CloseWindow()
	rl.SetTargetFPS(500)
	rl.SetExitKey(.ESCAPE)

	for !rl.WindowShouldClose() {
		input_process(&input)
		update()
		render()
	}
}

update :: proc() {

}

render :: proc() {

}

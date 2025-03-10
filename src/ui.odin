package pathways

import rl "vendor:raylib"

ui_tileset: rl.Texture2D

ui_setup :: proc() {
	ui_tileset = rl.LoadTexture("res/ui.png")
}

ui_draw :: proc() {
	// rl.DrawTexturePro(
	// 	ui_tileset,
	// 	{0, 0, 32 * 5, 32 * 4},
	// 	{10, WINDOW_HEIGHT - 32 * 5 * 2 - 64 - 10, 32 * 5 * 2, 32 * 4 * 2},
	// 	{0, 0},
	// 	0,
	// 	rl.WHITE,
	// )
}

ui_update :: proc() -> bool {
	return false
}

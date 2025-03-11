package pathways

import rl "vendor:raylib"

SRC_UI_TILE_SIZE :: 19
SRC_UI_BORDER_TILE_SIZE :: 4
SRC_UI_BOTTOM_BORDER_TILE_SIZE :: 4
SRC_UI_BUTTON_TILE_SIZE :: 10

UI_TILE_SIZE :: SRC_UI_TILE_SIZE * SCALE
UI_BORDER_TILE_SIZE :: SRC_UI_BORDER_TILE_SIZE * SCALE
UI_BOTTOM_BORDER_TILE_SIZE :: SRC_UI_BOTTOM_BORDER_TILE_SIZE * SCALE
UI_BUTTON_TILE_SIZE :: SRC_UI_BUTTON_TILE_SIZE * SCALE

UI_BG_GRAY :: rl.Color{192, 199, 200, 255}

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

ui_draw_window :: proc(x, y, width, height: f32, bg_colour: rl.Color, has_shadow := false) {
	shadow_size: f32 = 4
	rl.DrawRectangleRec(
		{x + shadow_size, y + shadow_size, width, height},
		rl.BLACK - {0, 0, 0, 80},
	)
	ui_window_top(x, y, width)
	ui_window_middle(x, y, width, height, bg_colour)
	ui_window_bottom(x, y, width, height)
}

ui_window_top :: proc(x, y, width: f32) {
	// Left corner
	rl.DrawTexturePro(
		ui_tileset,
		{0, 0, SRC_UI_TILE_SIZE, SRC_UI_TILE_SIZE},
		{x, y, UI_TILE_SIZE, UI_TILE_SIZE},
		{0, 0},
		0,
		rl.WHITE,
	)

	// Middle
	rl.DrawTexturePro(
		ui_tileset,
		{SRC_UI_TILE_SIZE * 1, 0, SRC_UI_TILE_SIZE, SRC_UI_TILE_SIZE},
		{x + UI_TILE_SIZE * 1, y, width - UI_TILE_SIZE * 2, UI_TILE_SIZE},
		{0, 0},
		0,
		rl.WHITE,
	)

	// Right corner
	rl.DrawTexturePro(
		ui_tileset,
		{SRC_UI_TILE_SIZE * 2, 0, SRC_UI_TILE_SIZE, SRC_UI_TILE_SIZE},
		{x + width - UI_TILE_SIZE, y, UI_TILE_SIZE, UI_TILE_SIZE},
		{0, 0},
		0,
		rl.WHITE,
	)

	// Button
	rl.DrawTexturePro(
		ui_tileset,
		{
			SRC_UI_TILE_SIZE * 3,
			SRC_UI_BUTTON_TILE_SIZE * 2,
			SRC_UI_BUTTON_TILE_SIZE,
			SRC_UI_BUTTON_TILE_SIZE,
		},
		{x + width - UI_BUTTON_TILE_SIZE - 10, y + 11, UI_BUTTON_TILE_SIZE, UI_BUTTON_TILE_SIZE},
		{0, 0},
		0,
		rl.WHITE,
	)
}

ui_window_middle :: proc(x, y, width, height: f32, bg_colour: rl.Color) {
	// Background
	rl.DrawRectangleRec(
		{
			x + UI_BORDER_TILE_SIZE,
			y + UI_TILE_SIZE * 1,
			width - UI_BORDER_TILE_SIZE,
			height - UI_BOTTOM_BORDER_TILE_SIZE - UI_TILE_SIZE,
		},
		bg_colour,
	)

	// Left border
	rl.DrawTexturePro(
		ui_tileset,
		{0, SRC_UI_TILE_SIZE, SRC_UI_BORDER_TILE_SIZE, SRC_UI_TILE_SIZE},
		{x, y + UI_TILE_SIZE * 1, UI_BORDER_TILE_SIZE, height - UI_TILE_SIZE},
		{0, 0},
		0,
		rl.WHITE,
	)

	// Right border
	rl.DrawTexturePro(
		ui_tileset,
		{
			SRC_UI_TILE_SIZE * 2 + (SRC_UI_TILE_SIZE - SRC_UI_BORDER_TILE_SIZE),
			SRC_UI_TILE_SIZE,
			SRC_UI_BORDER_TILE_SIZE,
			SRC_UI_TILE_SIZE,
		},
		{
			x + width - UI_BORDER_TILE_SIZE,
			y + UI_TILE_SIZE * 1,
			UI_BORDER_TILE_SIZE,
			height - UI_TILE_SIZE,
		},
		{0, 0},
		0,
		rl.WHITE,
	)
}

ui_window_bottom :: proc(x, y, width, height: f32) {
	// Left corner
	rl.DrawTexturePro(
		ui_tileset,
		{
			0,
			SRC_UI_TILE_SIZE * 2 + (SRC_UI_TILE_SIZE - SRC_UI_BOTTOM_BORDER_TILE_SIZE),
			SRC_UI_BOTTOM_BORDER_TILE_SIZE,
			SRC_UI_BORDER_TILE_SIZE,
		},
		{x, y + height - UI_BORDER_TILE_SIZE, UI_BORDER_TILE_SIZE, UI_BOTTOM_BORDER_TILE_SIZE},
		{0, 0},
		0,
		rl.WHITE,
	)

	// Middle
	rl.DrawTexturePro(
		ui_tileset,
		{
			SRC_UI_TILE_SIZE,
			SRC_UI_TILE_SIZE * 2 + (SRC_UI_TILE_SIZE - SRC_UI_BOTTOM_BORDER_TILE_SIZE),
			SRC_UI_BORDER_TILE_SIZE,
			SRC_UI_BOTTOM_BORDER_TILE_SIZE,
		},
		{
			x + UI_BORDER_TILE_SIZE * 1,
			y + height - UI_BORDER_TILE_SIZE,
			width - UI_BORDER_TILE_SIZE * 2,
			UI_BOTTOM_BORDER_TILE_SIZE,
		},
		{0, 0},
		0,
		rl.WHITE,
	)

	// Right corner
	rl.DrawTexturePro(
		ui_tileset,
		{
			SRC_UI_TILE_SIZE * 2 + (SRC_UI_TILE_SIZE - SRC_UI_BOTTOM_BORDER_TILE_SIZE),
			SRC_UI_TILE_SIZE * 2 + (SRC_UI_TILE_SIZE - SRC_UI_BOTTOM_BORDER_TILE_SIZE),
			SRC_UI_BOTTOM_BORDER_TILE_SIZE,
			SRC_UI_BORDER_TILE_SIZE,
		},
		{
			x + width - UI_BORDER_TILE_SIZE,
			y + height - UI_BORDER_TILE_SIZE,
			UI_BORDER_TILE_SIZE,
			UI_BOTTOM_BORDER_TILE_SIZE,
		},
		{0, 0},
		0,
		rl.WHITE,
	)
}

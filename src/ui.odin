package pathways

import "core:fmt"
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
UI_FONT_SIZE :: 18

Window :: struct {
	rec:   rl.Rectangle,
	title: string,
}

ui_tileset: rl.Texture2D
windows: [dynamic]Window
pos: rl.Rectangle

ui_setup :: proc() {
	ui_tileset = rl.LoadTexture("res/ui.png")

	win_width := f32(tileset.width * SCALE) + UI_BORDER_TILE_SIZE * 2
	win_height := f32(tileset.height * SCALE) + UI_BOTTOM_BORDER_TILE_SIZE + UI_TILE_SIZE

	append(
		&windows,
		Window {
			title = "Track pieces",
			rec = rl.Rectangle {
				f32(rl.GetScreenWidth()) - win_width - WIN_PADDING * 2,
				UI_TILE_SIZE + WIN_PADDING * 1.5,
				win_width,
				win_height,
			},
		},
	)

	pos = windows[0].rec
	pos.x += UI_BORDER_TILE_SIZE
	pos.y += UI_TILE_SIZE
	pos.width = f32(tileset.width * SCALE)
	pos.height = f32(tileset.height * SCALE)
}

ui_draw :: proc() {
	for w in windows {
		ui_draw_window(w.rec, w.title, UI_BG_GRAY, true)
	}

	rl.DrawTexturePro(
		tileset,
		{0, 0, f32(tileset.width), f32(tileset.height)},
		pos,
		{0, 0},
		0,
		rl.WHITE,
	)
}

ui_update :: proc() -> bool {
	for &w in windows {
		if !rl.CheckCollisionPointRec(input.mouse.pos_px, w.rec) {
			return false
		}

		if .LEFT in input.mouse.btns {
			titlebar := rl.Rectangle{w.rec.x, w.rec.y, w.rec.width, UI_TILE_SIZE}
			if rl.CheckCollisionPointRec(input.mouse.pos_px, titlebar) {
				fmt.printfln("in titlebar")
				w.rec.x = input.mouse.pos_px.x
				w.rec.y = input.mouse.pos_px.y
			}
		}
	}

	return false
}

ui_draw_window :: proc(
	win_rec: rl.Rectangle,
	title: string,
	bg_colour: rl.Color,
	has_shadow := false,
) {
	if has_shadow {
		shadow_size: f32 = 4
		rl.DrawRectangleRec(
			{win_rec.x + shadow_size, win_rec.y + shadow_size, win_rec.width, win_rec.height},
			rl.BLACK - {0, 0, 0, 80},
		)
	}
	ui_window_top(win_rec.x, win_rec.y, win_rec.width, title)
	ui_window_middle(win_rec.x, win_rec.y, win_rec.width, win_rec.height, bg_colour)
	ui_window_bottom(win_rec.x, win_rec.y, win_rec.width, win_rec.height)
}

ui_window_top :: proc(x, y, width: f32, title: string) {
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

	// Draw Title
	rl.DrawText(fmt.ctprintf("%s", title), i32(x) + 10, i32(y) + 10, UI_FONT_SIZE, rl.WHITE)

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

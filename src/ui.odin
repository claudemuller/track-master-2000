package pathways

import "core:fmt"
import "core:math"
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
UI_FONT_SIZE :: 20

Window :: struct {
	title:          string,
	rec:            rl.Rectangle,
	drag_start_rec: rl.Rectangle,
	dragging:       bool,
	buttons:        struct {
		close:    Button,
		maximise: Button,
		minimise: Button,
	},
}

Button :: struct {
	pos_px: rl.Rectangle,
	type:   ButtonType,
}

ButtonType :: enum {
	CLOSE,
}

ui_tileset: rl.Texture2D
windows: [dynamic]Window
track_tiles: rl.Rectangle
font: rl.Font

ui_setup :: proc() {
	ui_tileset = rl.LoadTexture("res/ui.png")
	font = rl.LoadFont("res/VT323-Regular.ttf")

	win_width := f32(tileset.width * SCALE) + UI_BORDER_TILE_SIZE * 2
	win_rec := rl.Rectangle {
		x      = f32(rl.GetScreenWidth()) - win_width - WIN_PADDING * 2,
		y      = f32(UI_TILE_SIZE + WIN_PADDING * 1.5),
		height = f32(tileset.height * SCALE) + UI_BOTTOM_BORDER_TILE_SIZE + UI_TILE_SIZE,
		width  = win_width,
	}
	append(&windows, ui_new_window("Track pieces", win_rec))

	track_tiles = windows[0].rec
	track_tiles.x += UI_BORDER_TILE_SIZE
	track_tiles.y += UI_TILE_SIZE
	track_tiles.width = f32(tileset.width * SCALE)
	track_tiles.height = f32(tileset.height * SCALE)
}

ui_draw :: proc() {
	for w in windows {
		ui_draw_window(w.title, w.rec, UI_BG_GRAY, true)
	}

	// Draw the tileset
	rl.DrawTexturePro(
		tileset,
		{0, 0, f32(tileset.width), f32(tileset.height)},
		track_tiles,
		{0, 0},
		0,
		rl.WHITE,
	)

	// Draw the selected tile
	if game_mem.selected_tile.type != .NONE {
		dst := rl.Rectangle {
			track_tiles.x + f32(game_mem.selected_tile.pos_grid.x * TILE_SIZE),
			track_tiles.y + f32(game_mem.selected_tile.pos_grid.y * TILE_SIZE),
			TILE_SIZE,
			TILE_SIZE,
		}
		rl.DrawRectangleLinesEx(dst, 1, rl.RED)
		// fmt.printfln("%v %v %v", track_tiles, selected_tile, dst)
	}
}

ui_update :: proc() -> bool {
	for &w in windows {
		if !rl.CheckCollisionPointRec(input.mouse.pos_px, w.rec) {
			return false
		}

		if .LEFT in input.mouse.btns {
			// w.dragging = true

			// Handle window button presses
			if rl.CheckCollisionPointRec(input.mouse.pos_px, w.buttons.close.pos_px) {
				fmt.printfln("close pressed")
				// append(&windows, ui_new_window("test", {200, 200, 200, 200}))
			}

			// Handle track_tiles button presses
			if rl.CheckCollisionPointRec(input.mouse.pos_px, track_tiles) {
				// Store tileset grid x and y
				// BUG:(lukefilewalker) x is not correct :(
				x := math.floor_f32((input.mouse.pos_px.x - track_tiles.x) / TILE_SIZE)
				// BUG:(lukefilewalker) y is messed up :(
				y := math.floor_f32((input.mouse.pos_px.y - track_tiles.y) / TILE_SIZE)

				game_mem.selected_tile = {
					pos_grid = {x, y},
					src_px   = {
						x * SRC_TILE_SIZE,
						y * SRC_TILE_SIZE,
						SRC_TILE_SIZE,
						SRC_TILE_SIZE,
					},
					pos_px   = {0, 0, TILE_SIZE, TILE_SIZE},
					type     = .TRACK,
				}
			}
		} else {
			w.dragging = false
		}

		if w.dragging {
			w.drag_start_rec = w.rec
			titlebar := rl.Rectangle{w.rec.x, w.rec.y, w.rec.width, UI_TILE_SIZE}
			if rl.CheckCollisionPointRec(input.mouse.pos_px, titlebar) {
				fmt.printfln("in titlebar")
				w.rec.x = w.drag_start_rec.x + input.mouse.pos_px.x
				w.rec.y = w.drag_start_rec.y + input.mouse.pos_px.y
			}
		}
	}

	return true
}

ui_new_window :: proc(title: string, rec: rl.Rectangle) -> Window {
	return Window {
		title = title,
		rec = rec,
		buttons = {
			close = {
				pos_px = {
					rec.x + rec.width - UI_BUTTON_TILE_SIZE - 10,
					rec.y + 10,
					UI_BUTTON_TILE_SIZE,
					UI_BUTTON_TILE_SIZE,
				},
			},
		},
	}
}

ui_draw_window :: proc(
	title: string,
	win_rec: rl.Rectangle,
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
	rl.DrawTextEx(font, fmt.ctprintf("%s", title), {x + 15, y + 10}, UI_FONT_SIZE, 1.5, rl.WHITE)

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
		{x + width - UI_BUTTON_TILE_SIZE - 10, y + 10, UI_BUTTON_TILE_SIZE, UI_BUTTON_TILE_SIZE},
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

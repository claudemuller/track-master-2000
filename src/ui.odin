package tm2000

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
UI_HORIZONTAL_RULE_SIZE :: 20
UI_BUTTON_SIZE :: 40
UI_BUTTON_PADDING :: 10
UI_WINDOW_PADDING :: 10

UI_BG_GRAY :: rl.Color{192, 199, 200, 255}
UI_FONT_SIZE :: 20

Window :: struct {
	title:          string,
	rec:            rl.Rectangle,
	drag_start_rec: rl.Rectangle,
	dragging:       bool,
	// TODO:(lukefilewalker) bitset rather?
	ctrl_buttons:   struct {
		close:    Button,
		maximise: Button,
		minimise: Button,
	},
	buttons:        []Button,
	text:           string,
	bg_colour:      rl.Color,
	padding:        f32,
	has_shadow:     bool,
}

Button :: struct {
	pos_px:   rl.Rectangle,
	type:     ButtonType,
	label:    string,
	on_click: proc(),
}

ButtonType :: enum {
	CLOSE,
}

ui_tileset: rl.Texture2D
windows: [dynamic]Window
buttons: [dynamic]Button
track_tiles: rl.Rectangle
font: rl.Font
tile_nums: map[u16]i32

ui_setup :: proc() {
	ui_tileset = rl.LoadTexture("res/ui.png")
	font = rl.LoadFont("res/VT323-Regular.ttf")

	// Create track tiles window
	tt_win_width := f32(tileset.width * SCALE) + UI_BORDER_TILE_SIZE * 2
	tt_win_rec := rl.Rectangle {
		x      = f32(rl.GetScreenWidth()) - tt_win_width - WIN_PADDING * 2,
		y      = f32(UI_TILE_SIZE + WIN_PADDING * 1.5),
		height = f32(
			tileset.height * SCALE,
		) + UI_BOTTOM_BORDER_TILE_SIZE + UI_TILE_SIZE + UI_HORIZONTAL_RULE_SIZE + UI_BUTTON_SIZE,
		width  = tt_win_width,
	}
	tt_btns := []Button{ui_new_button(0, track_tiles.height + 10, tt_win_rec, "Simulate", nil)}
	track_tiles_win := ui_new_window("Track pieces", tt_win_rec, "", tt_btns, 0, UI_BG_GRAY)

	append(&windows, track_tiles_win)

	track_tiles = windows[0].rec
	track_tiles.x += UI_BORDER_TILE_SIZE
	track_tiles.y += UI_TILE_SIZE
	track_tiles.width = f32(tileset.width * SCALE)
	track_tiles.height = f32(tileset.height * SCALE)

	// Calculate number of available times
	tile_nums = make(map[u16]i32)
	for pt in path_tiles {
		hash := gen_hash(i32(pt.src_px.x / SRC_TILE_SIZE), i32(pt.src_px.y / SRC_TILE_SIZE))
		tile_nums[hash] += 1
	}

	// Create welcome window
	w_win_width: f32 = 500
	w_win_rec := rl.Rectangle {
		x      = f32(rl.GetScreenWidth()) - w_win_width - WIN_PADDING * 2,
		y      = f32(300 + WIN_PADDING * 1.5),
		height = 300 + UI_BOTTOM_BORDER_TILE_SIZE + UI_TILE_SIZE + UI_HORIZONTAL_RULE_SIZE + UI_BUTTON_SIZE,
		width  = w_win_width,
	}
	w_btns := []Button{}
	w_txt := "Welcome to Track Master 2000"
	welcome_win := ui_new_window(
		"Welcome",
		w_win_rec,
		w_txt,
		w_btns,
		UI_WINDOW_PADDING,
		UI_BG_GRAY,
	)
	welcome_win.ctrl_buttons.close.on_click = proc() {
		fmt.printfln("closing welcome win")
		game_mem.state = .PLAYING
	}

	append(&windows, welcome_win)
}

ui_draw :: proc() {
	for w in windows {
		ui_draw_window(w)
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

	// Draw tile number indicator
	// TODO:(lukefilewalker) horrendous perf :((((((
	i := 0
	for k, v in tile_nums {
		// Ignore the last tile
		// if i == len(tile_nums) - 1 {
		// 	break
		// }
		// i += 1

		for x in 0 ..< i32(tileset.width / SRC_TILE_SIZE) {
			for y in 0 ..< i32(tileset.height / SRC_TILE_SIZE) {
				hash := gen_hash(x, y)

				// Draw tile outlines
				dst := rl.Rectangle {
					f32(x) * TILE_SIZE + track_tiles.x,
					f32(y) * TILE_SIZE + track_tiles.y,
					TILE_SIZE,
					TILE_SIZE,
				}
				rl.DrawRectangleLinesEx(dst, 1, rl.GRAY)

				if hash == k {
					// fmt.printfln("h:%v k:%v v:%v", hash, k, tile_nums[k])

					px_x := x * TILE_SIZE + i32(track_tiles.x) + (TILE_SIZE - 10)
					px_y := y * TILE_SIZE + i32(track_tiles.y) + (TILE_SIZE - 10)

					rl.DrawCircle(px_x, px_y, 10, rl.RED)

					lbl := fmt.ctprintf("%d", v)
					lbl_size: f32 = 15
					lbl_w := rl.MeasureText(lbl, i32(lbl_size))

					rl.DrawTextEx(
						font,
						lbl,
						{f32(px_x) - lbl_size / 4, f32(px_y) - lbl_size / 2},
						lbl_size,
						1,
						rl.BLACK,
					)
				}
			}
		}
	}

	if game_mem.state == .PLAYING {
		// Draw the selected tile
		if game_mem.selected_tile.type != .NONE {
			dst := rl.Rectangle {
				track_tiles.x + f32(game_mem.selected_tile.pos_grid.x * TILE_SIZE),
				track_tiles.y + f32(game_mem.selected_tile.pos_grid.y * TILE_SIZE),
				TILE_SIZE,
				TILE_SIZE,
			}
			rl.DrawRectangleLinesEx(dst, 1, rl.RED)
		}

		ui_draw_countdown_timer()
	}
}

ui_update :: proc() -> bool {
	for &w in windows {
		if !rl.CheckCollisionPointRec(input.mouse.pos_px, w.rec) {
			continue
		}

		fmt.printfln("%s", w.title)

		if .LEFT in input.mouse.btns {
			// w.dragging = true

			// Handle window button presses
			for b in w.buttons {
				if rl.CheckCollisionPointRec(input.mouse.pos_px, b.pos_px) {
					fmt.printfln("button clicked")
					if b.on_click != nil {
						b.on_click()
					}
				}
			}

			// Check for clicks on close button
			if rl.CheckCollisionPointRec(input.mouse.pos_px, w.ctrl_buttons.close.pos_px) {
				fmt.printfln("ctrl button clicked")
				if w.ctrl_buttons.close.on_click != nil {
					w.ctrl_buttons.close.on_click()
				}
			}

			// Handle track_tiles button presses
			if rl.CheckCollisionPointRec(input.mouse.pos_px, track_tiles) {
				// Store tileset grid x and y
				x := math.floor_f32((input.mouse.pos_px.x - track_tiles.x) / TILE_SIZE)
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

ui_new_window :: proc(
	title: string,
	rec: rl.Rectangle,
	text: string,
	buttons: []Button,
	padding: f32,
	bg_colour: rl.Color,
) -> Window {
	return Window {
		title = title,
		rec = rec,
		bg_colour = bg_colour,
		buttons = buttons,
		text = text,
		padding = padding,
		ctrl_buttons = {
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

ui_draw_window :: proc(win: Window) {
	if win.has_shadow {
		shadow_size: f32 = 4
		rl.DrawRectangleRec(
			{win.rec.x + shadow_size, win.rec.y + shadow_size, win.rec.width, win.rec.height},
			rl.BLACK - {0, 0, 0, 80},
		)
	}
	ui_window_top(win.rec.x, win.rec.y, win.rec.width, win.title)
	ui_window_middle(win.rec.x, win.rec.y, win.rec.width, win.rec.height, win.bg_colour)
	ui_window_bottom(win.rec.x, win.rec.y, win.rec.width, win.rec.height)

	rl.DrawTextEx(
		font,
		fmt.ctprint(win.text),
		win.rec.x + win.padding,
		win.rec.y + UI_TILE_SIZE + win.padding,
		1,
		rl.BLACK,
	)

	for b in buttons {
		ui_draw_button(b)
	}
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

	// Debug
	rl.DrawRectangleLinesEx(
		{x + width - UI_BUTTON_TILE_SIZE - 10, y + 10, UI_BUTTON_TILE_SIZE, UI_BUTTON_TILE_SIZE},
		1,
		rl.RED,
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

ui_new_button :: proc(x, y: f32, win: rl.Rectangle, label: string, on_click: proc()) -> Button {
	w := rl.MeasureText(fmt.ctprintf("%s", label), UI_FONT_SIZE)
	return Button {
		pos_px = {
			win.x + UI_BUTTON_PADDING + x,
			win.y + y,
			f32(w) + UI_BUTTON_PADDING,
			UI_FONT_SIZE + UI_BUTTON_PADDING * 2,
		},
		label = label,
		on_click = on_click,
	}
}

ui_draw_button :: proc(b: Button) {
	pos := rl.Vector2{b.pos_px.x, b.pos_px.y}
	lbl_pos := pos
	size := rl.Vector2{b.pos_px.width, b.pos_px.height}

	rl.DrawRectangleV(pos, size, rl.WHITE)
	rl.DrawRectangleV(pos + {2, 2}, size, rl.BLACK)
	rl.DrawRectangleV(pos + {2, 2}, size - {4, 4}, rl.GRAY)

	rl.DrawTextEx(
		font,
		fmt.ctprintf("%s", b.label),
		lbl_pos + {UI_BUTTON_PADDING, UI_BUTTON_PADDING},
		UI_FONT_SIZE,
		1,
		rl.BLACK,
	)

	// Debug
	rl.DrawRectangleLinesEx({pos.x, pos.y, size.x, size.y}, 1, rl.RED)
}

ui_draw_countdown_timer :: proc() {
	// Draw countdown
	countdown_size: i32 = 25
	countdown_txt := fmt.ctprintf(
		"Imminent danger in: %d",
		i32(LEVEL_TIME_LIMIT - get_elapsed(level_end)),
	)
	txt_w := rl.MeasureText(countdown_txt, countdown_size)
	txt_h: i32 = 50
	txt_x := rl.GetScreenWidth() / 2 - txt_w / 2
	txt_y := tile_y_offset + 10
	rl.DrawRectangle(txt_x - 20, txt_y - 10, txt_w + 40, txt_h, rl.BLACK - {0, 0, 0, 100})
	rl.DrawText(countdown_txt, txt_x, txt_y, countdown_size, rl.RED)
}

ui_draw_horizontal_rule :: proc(start: rl.Vector2, length: f32) {
	end := start + {length, 0}
	rl.DrawLineV(start, end, rl.LIGHTGRAY)
	rl.DrawLineV(start + {1, 0}, end + {1, 0}, rl.GRAY)
}

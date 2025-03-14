package tm2000

GameState :: enum {
	BOOTING,
	MAIN_MENU,
	PLAYING,
	SIMULATING,
	WIN,
	GAME_OVER,
	EXIT,
}

game_get_state :: proc() -> GameState {
	return game_mem.state[0]
}

game_get_prev_state :: proc() -> GameState {
	return game_mem.state[1]
}

game_push_state :: proc(state: GameState) {
	temp_state := game_mem.state[0]
	game_mem.state[0] = state
	game_mem.state[1] = temp_state
}

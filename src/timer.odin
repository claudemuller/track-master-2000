package tm2000

import rl "vendor:raylib"

Timer :: struct {
	start_time: f64,
	life_time:  f64,
}

start_timer :: proc(timer: ^Timer, lifetime: f64) {
	timer.start_time = rl.GetTime()
	timer.life_time = lifetime
}

timer_done :: proc(timer: Timer) -> bool {
	return rl.GetTime() - timer.start_time >= timer.life_time
}

get_elapsed :: proc(timer: Timer) -> f64 {
	return rl.GetTime() - timer.start_time
}

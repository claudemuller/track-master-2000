package tm2000

gen_hash :: proc(x, y: i32) -> u16 {
	return u16(((x * 73856093) + (y * 19349663)) % 65536)
}

btof :: proc(b: bool) -> f32 {
	return b ? 1.0 : 0.0
}

package game

import "core:slice"

draw_line_x :: proc(y: i32, buffer: OffScreenBuffer) {
	pixels := buffer.data[y * buffer.width:(y + 1) * buffer.width]
	slice.fill(pixels, RED)
}

draw_line_y :: proc(x: i32, buffer: OffScreenBuffer) {
	for row in 0 ..< buffer.height {
		buffer.data[row * buffer.width + x] = RED
	}
}

draw_dot :: proc(pos: [2]i32, buffer: OffScreenBuffer) {
	if (pos.x < 0 || pos.x >= buffer.width || pos.y < 0 || pos.y >= buffer.height) {
		return
	}
	buffer.data[pos.y * buffer.width + pos.x] = BLUE
}

draw_debug_world_rect :: proc(min, max: V2, color: u32, buffer: OffScreenBuffer) {
	// 世界坐标 y 向上；屏幕 y 向下，所以屏幕左上角对应 world 的 (min.x, max.y)
	top_left := rel_pos_to_buffer_pos(V3{min.x, max.y, 0}, buffer)
	size := meter_to_pixel(max - min)

	draw_rectangle(top_left, size, color, buffer, true)
}

draw_debug_world_dot :: proc(pos: V2, color: u32, buffer: OffScreenBuffer) {
	pixel := rel_pos_to_buffer_pos(V3{pos.x, pos.y, 0}, buffer)
	if pixel.x >= 0 && pixel.x < buffer.width && pixel.y >= 0 && pixel.y < buffer.height {
		buffer.data[pixel.y * buffer.width + pixel.x] = color
	}
}

draw_debug_world_line :: proc(from, to: V2, color: u32, buffer: OffScreenBuffer) {
	// Fixed samples keep this helper small while making the short per-frame rays visible.
	for i in 0 ..< 65 {
		t := f32(i) / 64
		draw_debug_world_dot(from + (to - from) * t, color, buffer)
	}
}

draw_collision_debug :: proc(debug: CollisionDebug, buffer: OffScreenBuffer) {
	if !debug.valid {
		return
	}

	// Yellow: Minkowski-expanded AABB. Cyan: B-origin local ray used by sweep.
	// Blue: A's real movement. Magenta: calculated hit point.
	draw_debug_world_rect(debug.expanded_min, debug.expanded_max, YELLOW, buffer)
	draw_debug_world_line(debug.relative_ray_start, debug.relative_ray_end, CYAN, buffer)
	draw_debug_world_line(debug.actual_path_start, debug.actual_path_end, BLUE, buffer)
	draw_debug_world_dot(debug.relative_ray_start, CYAN, buffer)
	draw_debug_world_dot(debug.hit_point, MAGENTA, buffer)
}

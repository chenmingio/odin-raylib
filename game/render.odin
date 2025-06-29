package game
import "base:intrinsics"
import "core:slice"


// RGBA
RED := intrinsics.byte_swap(u32(0xFF0000FF))
GREEN := intrinsics.byte_swap(u32(0x00FF00FF))
BLUE := intrinsics.byte_swap(u32(0x0000FFFF))
BLACK := intrinsics.byte_swap(u32(0x000000FF))
WHITE := intrinsics.byte_swap(u32(0xFFFFFFFF))

OffScreenBuffer :: struct {
	data:   []u32,
	width:  u32,
	height: u32,
}

// pos is at the gravity center of entity
draw_entity_rectangle :: proc(
	pos: ScreenPos,
	width: u32,
	height: u32,
	color: u32,
	buffer: OffScreenBuffer,
) {
	center_x := i32(buffer.width) / 2 + i32(pos.x)
	center_y := i32(buffer.height) / 2 - i32(pos.y)

	draw_rectangle(center_x - i32(width) / 2, center_y - i32(height), width, height, color, buffer)
}

// for screen space, 00 is top left, 11 is bottom right
// x, y are top left
draw_rectangle :: proc(
	x: i32,
	y: i32,
	width: u32,
	height: u32,
	color: u32,
	buffer: OffScreenBuffer,
) {
	x := u32(max(0, x))
	y := u32(max(0, y))

	minX := min(x, buffer.width)
	maxX := min(x + width, buffer.width)
	minY := min(y, buffer.height)
	maxY := min(y + height, buffer.height)
	for row in minY ..< maxY {
		rowOffset := row * buffer.width
		pixels := buffer.data[rowOffset + minX:rowOffset + maxX]
		slice.fill(pixels, color)
	}
}

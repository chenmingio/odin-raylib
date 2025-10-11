package game
import "base:intrinsics"
import "core:fmt"
import "core:image"
import "core:mem"
import "core:slice"
import "core:testing"


// RGBA
RED := intrinsics.byte_swap(u32(0xFF0000FF))
GREEN := intrinsics.byte_swap(u32(0x00FF00FF))
BLUE := intrinsics.byte_swap(u32(0x0000FFFF))
BLACK := intrinsics.byte_swap(u32(0x000000FF))
WHITE := intrinsics.byte_swap(u32(0xFFFFFFFF))


OffScreenBuffer :: struct {
	data:   []u32,
	width:  i32,
	height: i32,
}

// pos is at the gravity center of entity
draw_entity_rectangle :: proc(
	pos: ScreenPos,
	width: i32,
	height: i32,
	color: u32,
	buffer: OffScreenBuffer,
) {
	center_x := buffer.width / 2 + i32(pos.x)
	center_y := buffer.height / 2 - i32(pos.y)

	draw_rectangle(center_x - width / 2, center_y - height / 2, width, height, color, buffer)
}

// for screen space, 00 is top left, 11 is bottom right
// x, y are top left
draw_rectangle :: proc(
	x: i32,
	y: i32,
	width: i32,
	height: i32,
	color: u32,
	buffer: OffScreenBuffer,
) {
	x := max(0, x)
	y := max(0, y)

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

draw_image :: proc(x: i32, y: i32, img: ^image.Image, buffer: OffScreenBuffer) {
	minX := clamp(x, 0, buffer.width)
	maxX := clamp(x + i32(img.width), minX, buffer.width)
	minY := clamp(y, 0, buffer.height)
	maxY := clamp(y + i32(img.height), minY, buffer.height)

	overlap := i32(maxX - minX)
	for target_row, source_row in minY ..< maxY {
		// image.pixels is []byte, so we need to multiply by 4 to get the correct offset
		source_start_byte := i32(source_row * img.width) * 4
		source := img.pixels.buf[source_start_byte:source_start_byte + overlap * 4]
		source_u32 := transmute([]u32)source

		target_start := target_row * buffer.width + minX
		target := buffer.data[target_start:target_start + overlap]

		copy(target, source_u32)
	}
}

intersect_images :: proc(a: Rectangle, b: Rectangle) -> (Rectangle, bool) {
	intersection := Rectangle{}

	intersection.min.x = max(a.min.x, b.min.x)
	intersection.min.y = max(a.min.y, b.min.y)
	intersection.max.x = min(a.max.x, b.max.x)
	intersection.max.y = min(a.max.y, b.max.y)

	exists := intersection.min.x < intersection.max.x && intersection.min.y < intersection.max.y

	return intersection, exists
}


// flat layout
draw_animation :: proc(
	x, y: i32,
	img: ^image.Image,
	buffer: OffScreenBuffer,
	frames: i32,
	frame_index: i32,
) {

	frame_img_width := i32(img^.width) / frames
	source_x_offset := frame_index * frame_img_width
	for row in 0 ..< img^.height {
		source_start_byte := i32(row * img^.width) + source_x_offset * 4
		souce_end_byte := source_start_byte + frame_img_width * 4
		source := img^.pixels.buf[source_start_byte:souce_end_byte]
		source_u32 := transmute([]u32)source

		target_offset := (i32(row) + y) * buffer.width + x
		target := buffer.data[target_offset:target_offset + frame_img_width]

		copy(target, source_u32)
	}
}


@(test)
test_image :: proc(t: ^testing.T) {
	img, err := image.load_from_file("resources/background_pink_sky.png")
	if err != nil {
		testing.fail(t)
		return
	}
	image.destroy(img)
}

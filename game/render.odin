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
draw_entity_as_rectangle :: proc(
	pos: V3,
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

draw_line_x :: proc(y: i32, buffer: OffScreenBuffer) {
	pixels := buffer.data[y * buffer.width:(y + 1) * buffer.width]
	slice.fill(pixels, RED)
}

draw_line_y :: proc(x: i32, buffer: OffScreenBuffer) {
	for row in 0 ..< buffer.height {
		buffer.data[row * buffer.width + x] = RED
	}
}

draw_image :: proc(x: i32, y: i32, img: ^image.Image, buffer: OffScreenBuffer) {
	minX := clamp(x, 0, buffer.width)
	maxX := clamp(x + i32(img.width), minX, buffer.width)
	minY := clamp(y, 0, buffer.height)
	maxY := clamp(y + i32(img.height), minY, buffer.height)

	overlap := i32(maxX - minX)
	for target_row in minY ..< maxY {
		// 计算正确的 source 坐标
		source_row := target_row - y // 相对于图像的行号

		// 边界检查
		if source_row < 0 || source_row >= i32(img.height) {
			continue
		}

		// image.pixels is []byte, so we need to multiply by 4 to get the correct offset
		source_start_byte := source_row * i32(img.width) * 4
		source_end_byte := source_start_byte + overlap * 4

		// 确保不越界
		if source_end_byte > i32(len(img.pixels.buf)) {
			continue
		}

		source := img.pixels.buf[source_start_byte:source_end_byte]
		source_u32 := transmute([]u32)source

		target_start := target_row * buffer.width + minX
		target := buffer.data[target_start:target_start + overlap]

		copy(target, source_u32)
	}
}

// 假设动画图片水平排列，一共有frames帧
draw_animation :: proc(x, y: i32, animate_img: ^AnimateImage, buffer: OffScreenBuffer) {

	full_image := animate_img^.image

	// in pixel
	single_width := i32(full_image^.width) / animate_img^.frame_count
	source_x_offset := animate_img^.frame_index * single_width

	// buffer上图片的四个角
	minX := clamp(x, 0, buffer.width)
	maxX := clamp(x + single_width, minX, buffer.width)
	minY := clamp(y, 0, buffer.height)
	maxY := clamp(y + i32(full_image^.height), minY, buffer.height)

	for source_row in 0 ..< (maxY - minY) {
		// 起始数据：宽度x行数 + offset
		source_start := source_row * i32(full_image^.width) + source_x_offset
		source_end := source_start + single_width
		source := full_image^.pixels.buf[source_start * 4:source_end * 4] // buf为byte
		// image.pixels是[]byte，而目标buffer.data是[]u32，所以需要转换
		source_u32 := transmute([]u32)source

		target_offset := i32(minY + source_row) * buffer.width + i32(minX)
		target := buffer.data[target_offset:target_offset + (maxX - minX)]

		copy(target, source_u32)
	}

	animate_img^.update_counter =
		(animate_img^.update_counter + 1) % animate_img^.updates_per_frame
	if animate_img^.update_counter == 0 {
		animate_img^.frame_index = (animate_img^.frame_index + 1) % animate_img^.frame_count
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


@(test)
test_image :: proc(t: ^testing.T) {
	img, err := image.load_from_file("resources/background_pink_sky.png")
	if err != nil {
		testing.fail(t)
		return
	}
	image.destroy(img)
}

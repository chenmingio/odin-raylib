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

// for screen space, 00 is top left, 11 is bottom right
// x, y are top left
draw_rectangle :: proc(
	x: i32,
	y: i32,
	width: i32,
	height: i32,
	color: u32,
	buffer: OffScreenBuffer,
	is_line: bool = false,
) {
	x := max(0, x)
	y := max(0, y)

	minX := min(x, buffer.width)
	maxX := min(x + width, buffer.width)
	minY := min(y, buffer.height)
	maxY := min(y + height, buffer.height)
	for row in minY ..< maxY {
		rowsOffset := row * buffer.width
		if is_line && (row != minY && row != maxY - 1) {
			buffer.data[rowsOffset + minX] = color
			buffer.data[rowsOffset + maxX] = color
		} else {
			pixels := buffer.data[rowsOffset + minX:rowsOffset + maxX]
			slice.fill(pixels, color)
		}
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
	// buffer上的位置
	minX := clamp(x, 0, buffer.width)
	maxX := clamp(x + i32(img.width), minX, buffer.width)
	minY := clamp(y, 0, buffer.height)
	maxY := clamp(y + i32(img.height), minY, buffer.height)

	// 图像上开始读取的位置
	offset_x := x >= 0 ? 0 : -x
	offset_y := y >= 0 ? 0 : -y

	for target_row in minY ..< maxY {
		// 计算正确的 source 坐标
		source_row := target_row - y // 相对于图像的行号

		// image.pixels is []byte, so we need to multiply by 4 to get the correct offset
		source_start := (source_row) * i32(img.width) + offset_x
		source_end := source_start + (maxX - minX)

		source := img.pixels.buf[source_start * 4:source_end * 4]
		source_u32 := transmute([]u32)source

		target_start := target_row * buffer.width + minX
		target := buffer.data[target_start:target_start + maxX - minX]

		copy(target, source_u32)
	}
}

// 假设动画图片水平排列，一共有frames帧
draw_animation :: proc(pos: V2i, size: V2i, animate_img: ^AnimateImage, buffer: OffScreenBuffer) {

	full_image := animate_img^.image

	// in pixel
	single_frame_width := i32(full_image^.width) / animate_img^.frame_count
	frame_offset := V2i {
		// frame偏移+frame内部图像偏移
		animate_img^.frame_index * single_frame_width + (single_frame_width - size.x) / 2,
		(i32(full_image^.height) - size.y) / 2,
	}

	// 定位图片在buffer上的四个角
	minX := clamp(pos.x, 0, buffer.width)
	maxX := clamp(pos.x + size.x, minX, buffer.width)
	minY := clamp(pos.y, 0, buffer.height)
	maxY := clamp(pos.y + size.y, minY, buffer.height)

	source_offset := V2i{max(-pos.x, 0), max(-pos.y, 0)}

	for target_row in minY ..< maxY {
		// 起始数据：宽度x行数 + offset
		idx := target_row - minY
		source_start :=
			(source_offset.y + idx + frame_offset.y) * i32(full_image^.width) + frame_offset.x
		source_end := source_start + single_frame_width // 最大值
		source := full_image^.pixels.buf[source_start * 4:source_end * 4] // buf为byte
		// image.pixels是[]byte，而目标buffer.data是[]u32，所以需要转换
		source_u32 := transmute([]u32)source

		target_offset := minY * buffer.width + minX
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

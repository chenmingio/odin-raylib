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

blend :: proc(target, source: []u32) {
	for i in 0 ..< len(target) {
		// 先把内部像素格式转换成标准 RGBA（与上面的常量定义一致）
		c_dst := intrinsics.byte_swap(target[i])
		c_src := intrinsics.byte_swap(source[i])

		rd := c_dst >> 24 & 0xFF
		gd := c_dst >> 16 & 0xFF
		bd := c_dst >> 8 & 0xFF
		ad := c_dst & 0xFF

		rs := c_src >> 24 & 0xFF
		gs := c_src >> 16 & 0xFF
		bs := c_src >> 8 & 0xFF
		as := c_src & 0xFF

		// 非预乘 alpha: Cout = Cs * As + Cd * (1 - As)
		r_out := (rd * (255 - as) + rs * as) / 255
		g_out := (gd * (255 - as) + gs * as) / 255
		b_out := (bd * (255 - as) + bs * as) / 255
		// Aout = As + Ad * (1 - As)
		a_out := as + (ad * (255 - as)) / 255

		c_out := (r_out << 24) | (g_out << 16) | (b_out << 8) | a_out
		// 再转换回内部像素格式
		target[i] = intrinsics.byte_swap(c_out)
	}
}

// size: 图片crop的尺寸
draw_image :: proc(
	pos: V2i,
	img: ^image.Image,
	buffer: OffScreenBuffer,
	size: V2i = V2i{},
	offset: V2i = V2i{},
) {

	assert(offset.x >= 0 && offset.y >= 0)

	// buffer上从哪里开始画
	minX := clamp(pos.x, 0, buffer.width)
	maxX := clamp(pos.x + min(size.x, i32(img^.width) - offset.x), minX, buffer.width)
	minY := clamp(pos.y, 0, buffer.height)
	maxY := clamp(pos.y + min(size.y, i32(img^.height) - offset.y), minY, buffer.height)

	// 图像上开始读取的位置
	offset_x := (pos.x >= 0 ? 0 : -pos.x) + offset.x
	offset_y := (pos.y >= 0 ? 0 : -pos.y) + offset.y

	for target_row in minY ..< maxY {
		// 计算正确的 source 坐标
		source_row := target_row - pos.y + offset.y // 相对于图像的行号

		// image.pixels is []byte, so we need to multiply by 4 to get the correct offset
		source_start := (source_row) * i32(img.width) + offset_x
		source_end := source_start + (maxX - minX)

		source := img.pixels.buf[source_start * 4:source_end * 4]
		source_u32 := transmute([]u32)source

		target_start := target_row * buffer.width + minX
		target := buffer.data[target_start:target_start + maxX - minX]

		blend(target, source_u32)
	}
}

// 假设动画图片水平排列，一共有frames帧
draw_animation :: proc(pos: V2i, size: V2i, animate_img: ^AnimateImage, buffer: OffScreenBuffer) {
	image := animate_img^.image

	// in pixel
	single_frame_width := i32(image^.width) / animate_img^.frame_count
	frame_offset := V2i {
		// frame偏移+frame内部图像偏移
		animate_img^.frame_index * single_frame_width + (single_frame_width - size.x) / 2,
		(i32(image^.height) - size.y) / 2,
	}

	draw_image(pos, image, buffer, size, frame_offset)

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

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

blend :: proc(target, source: []u32, reverse: bool = false) {
	assert(len(target) == len(source))
	for i in 0 ..< len(target) {
		si := reverse ? len(target) - i - 1 : i

		// 快速路径：全透明/全不透明
		// 注意：source/target 的内部像素格式一致，可直接赋值
		c_src_swapped := intrinsics.byte_swap(source[si])
		as := c_src_swapped & 0xFF
		if as == 0 {
			// 全透明：不改变目标像素
			continue
		}
		if as == 255 {
			// 全不透明：直接拷贝（避免所有计算和两次 byte_swap）
			target[i] = source[si]
			continue
		}

		// 一般路径：做标准 alpha 混合
		c_dst := intrinsics.byte_swap(target[i])
		rd := c_dst >> 24 & 0xFF
		gd := c_dst >> 16 & 0xFF
		bd := c_dst >> 8 & 0xFF
		ad := c_dst & 0xFF

		rs := c_src_swapped >> 24 & 0xFF
		gs := c_src_swapped >> 16 & 0xFF
		bs := c_src_swapped >> 8 & 0xFF

		r_out := (rd * (255 - as) + rs * as) / 255
		g_out := (gd * (255 - as) + gs * as) / 255
		b_out := (bd * (255 - as) + bs * as) / 255
		a_out := as + (ad * (255 - as)) / 255

		c_out := (r_out << 24) | (g_out << 16) | (b_out << 8) | a_out
		target[i] = intrinsics.byte_swap(c_out)
	}
}

// size: 图片crop的尺寸
draw_image_simple :: proc(
	pos: V2i,
	img: ^image.Image,
	buffer: OffScreenBuffer,
	reverse: bool = false,
) {

	// buffer上从哪里开始画
	minX := clamp(pos.x, 0, buffer.width)
	maxX := clamp(pos.x + i32(img^.width), minX, buffer.width)
	minY := clamp(pos.y, 0, buffer.height)
	maxY := clamp(pos.y + i32(img^.height), minY, buffer.height)

	// 图像上开始读取的位置
	offset_x := (pos.x >= 0 ? 0 : -pos.x)
	offset_y := (pos.y >= 0 ? 0 : -pos.y)

	for target_row in minY ..< maxY {
		// 计算正确的 source 坐标
		source_row := target_row - pos.y // 相对于图像的行号

		// image.pixels is []byte, so we need to multiply by 4 to get the correct offset
		source_start := (source_row) * i32(img^.width) + offset_x
		source_end := source_start + (maxX - minX)

		source := img^.pixels.buf[source_start * 4:source_end * 4]
		source_u32 := transmute([]u32)source

		target_start := target_row * buffer.width + minX
		target := buffer.data[target_start:target_start + maxX - minX]

		blend(target, source_u32, reverse)
	}
}

draw_tile_map :: proc(tile_pos: V2i, tile_idx: u8, img: ^image.Image, buffer: OffScreenBuffer) {
	tile_size := i32(img^.height / 6)
	tiles_per_row := max(1, i32(img^.width) / tile_size)

	atlas_x := (i32(tile_idx) % tiles_per_row) * tile_size
	atlas_y := (i32(tile_idx) / tiles_per_row) * tile_size

	x := tile_pos.x * tile_size
	y := tile_pos.y * tile_size
	draw_image_corp(V2i{x, y}, img, buffer, V2i{tile_size, tile_size}, V2i{atlas_x, atlas_y})
}

// size: 图片crop的尺寸
draw_image_corp :: proc(
	pos: V2i,
	img: ^image.Image, // 整个图片文件
	buffer: OffScreenBuffer,
	size: V2i = V2i{}, // 需要画出的部分的尺寸
	offset: V2i = V2i{}, // 需要画出的部分的偏移
	reverse: bool = false,
) {

	assert(offset.x >= 0 && offset.y >= 0)

	// buffer上从哪里开始画(pixels)
	minX := clamp(pos.x, 0, buffer.width)
	maxX := clamp(pos.x + min(size.x, i32(img^.width) - offset.x), minX, buffer.width)
	minY := clamp(pos.y, 0, buffer.height)
	maxY := clamp(pos.y + min(size.y, i32(img^.height) - offset.y), minY, buffer.height)

	// 图像上开始读取的位置
	offset_x := (pos.x >= 0 ? 0 : -pos.x) + offset.x
	offset_y := (pos.y >= 0 ? 0 : -pos.y) + offset.y

	// 将像素缓冲预先转换为 u32 视图，避免在每一行循环中重复 transmute
	pixels_u32 := (transmute([dynamic]u32)img^.pixels.buf)

	for target_row in minY ..< maxY {
		// 计算正确的 source 坐标
		source_row := target_row - pos.y + offset_y // 相对于图像的行号

		// image.pixels is []byte, so we need to multiply by 4 to get the correct offset
		source_start := (source_row) * i32(img^.width) + offset_x
		source_end := source_start + (maxX - minX)

		// bytes
		// source := (transmute([dynamic]u32)img^.pixels.buf)[source_start:source_end] //dynamic转换问题不太理解
		source := pixels_u32[source_start:source_end]

		target_start := target_row * buffer.width + minX
		target := buffer.data[target_start:target_start + maxX - minX]

		blend(target, source, reverse)
	}
}

// 假设动画图片水平排列，一共有frames帧
draw_animation :: proc(
	pos: V2i,
	animation: Animation,
	entity: ^Entity,
	buffer: OffScreenBuffer,
	dt: f32,
) {
	image := animation.image
	status := entity.status

	// in pixel
	clips := animation.clips[status].frames
	assert(len(clips) > 0)

	entity.anim_time += i32(dt * 1000)
	for entity.anim_time >= clips[entity.anim_frame_idx].duration {
		entity.anim_time -= clips[entity.anim_frame_idx].duration
		entity.anim_frame_idx = (entity.anim_frame_idx + 1) % i32(len(clips))
	}

	frame := clips[entity.anim_frame_idx]
	size := V2i{i32(frame.frame.w), i32(frame.frame.h)}
	offset := V2i{i32(frame.frame.x), i32(frame.frame.y)}
	pos := pos + animation.anchorOffset

	reverse := entity.direction == Direction.Backward
	draw_image_corp(pos, image, buffer, size, offset, reverse)
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

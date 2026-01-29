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

// 绘制矩形（填充或边框）
draw_rectangle :: proc(
	x: i32,
	y: i32,
	width: i32,
	height: i32,
	color: u32,
	buffer: OffScreenBuffer,
	outline: bool = false,
) {
	// 输入矩形
	rect := Rectangle{
		min = V2i{x, y},
		max = V2i{x + width, y + height},
	}

	// buffer 边界
	buffer_rect := Rectangle{
		min = V2i{0, 0},
		max = V2i{buffer.width, buffer.height},
	}

	// 求交集
	draw_rect, ok := intersect_rect(rect, buffer_rect)
	if !ok {
		return
	}

	for ty in draw_rect.min.y ..< draw_rect.max.y {
		row_start := ty * buffer.width

		if outline && ty != draw_rect.min.y && ty != draw_rect.max.y - 1 {
			// 边框模式：只画左右两个点
			buffer.data[row_start + draw_rect.min.x] = color
			buffer.data[row_start + draw_rect.max.x - 1] = color
		} else {
			// 填充模式：画整行
			pixels := buffer.data[row_start + draw_rect.min.x:row_start + draw_rect.max.x]
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
	full_size := V2i{i32(img^.width), i32(img^.height)}
	draw_image_corp(pos, img, buffer, sprite_size = full_size, reverse = reverse)
}

draw_tile_map :: proc(grid_pos: V2i, tile_idx: V2i, img: ^image.Image, buffer: OffScreenBuffer) {
	tiles_per_col :: 6
	tile_size := i32(img^.height / tiles_per_col)

	// 图集中 tile 的位置
	atlas_offset := V2i{tile_idx.x * tile_size, tile_idx.y * tile_size}

	// 屏幕上的位置
	screen_pos := V2i{
		grid_pos.x * tile_size + tile_size / 2,
		grid_pos.y * tile_size + tile_size / 2,
	}

	draw_image_corp(screen_pos, img, buffer, sprite_size = V2i{tile_size, tile_size}, atlas_offset = atlas_offset)
}

// 从图集中裁剪并绘制图像
//
// 概念模型：
//   1. sprite 放在 buffer 的 pos 位置，形成 sprite_rect
//   2. sprite_rect 和 buffer_rect 求交集，得到 draw_rect（buffer 坐标系）
//   3. 遍历 draw_rect 的每个点，反推 source 坐标，复制像素
//
draw_image_corp :: proc(
	pos: V2i,
	img: ^image.Image,
	buffer: OffScreenBuffer,
	sprite_size: V2i = V2i{},
	atlas_offset: V2i = V2i{},
	reverse: bool = false,
) {
	// sprite 在 buffer 上占据的矩形（buffer 坐标系）
	sprite_rect := Rectangle{
		min = pos,
		max = pos + sprite_size,
	}

	// buffer 边界
	buffer_rect := Rectangle{
		min = V2i{0, 0},
		max = V2i{buffer.width, buffer.height},
	}

	// 求交集 = 实际要绘制的区域（buffer 坐标系）
	draw_rect, ok := intersect_rect(sprite_rect, buffer_rect)
	if !ok {
		return // 完全不可见
	}

	pixels_u32 := transmute([dynamic]u32)img^.pixels.buf
	img_width := i32(img^.width)

	// 遍历 draw_rect 的每一行
	for ty in draw_rect.min.y ..< draw_rect.max.y {
		// 反推 source 坐标
		sy := ty - pos.y + atlas_offset.y
		sx := draw_rect.min.x - pos.x + atlas_offset.x

		// 这一行的宽度
		width := draw_rect.max.x - draw_rect.min.x

		// 获取 source 和 target 的行切片
		src_start := sy * img_width + sx
		source := pixels_u32[src_start:src_start + width]

		dst_start := ty * buffer.width + draw_rect.min.x
		target := buffer.data[dst_start:dst_start + width]

		blend(target, source, reverse)
	}
}

// 两个矩形求交集
intersect_rect :: proc(a, b: Rectangle) -> (Rectangle, bool) {
	result := Rectangle{
		min = V2i{max(a.min.x, b.min.x), max(a.min.y, b.min.y)},
		max = V2i{min(a.max.x, b.max.x), min(a.max.y, b.max.y)},
	}

	// 检查是否有效（有面积）
	ok := result.min.x < result.max.x && result.min.y < result.max.y
	return result, ok
}

draw_entity_image :: proc(
	pos: V2i,
	image: ^image.Image,
	entity: ^Entity,
	buffer: OffScreenBuffer,
) {
	draw_image_simple(pos, image, buffer)
	draw_rectangle(
		pos.x,
		pos.y,
		i32(meter_to_pixel(entity^.size.x)),
		i32(meter_to_pixel(entity^.size.y)),
		RED,
		buffer,
		outline = true,
	)
}

// 假设动画图片水平排列，一共有frames帧
draw_entity_animation :: proc(
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
	sprite_size := V2i{frame.frame.w, frame.frame.h}
	atlas_offset := V2i{frame.frame.x, frame.frame.y}
	// 调整位置：锚点偏移 - trimmed 偏移
	draw_pos := pos + animation.anchorOffset - V2i{frame.spriteSourceSize.x, frame.spriteSourceSize.y}

	reverse := entity.direction == Direction.Backward
	draw_image_corp(draw_pos, image, buffer, sprite_size, atlas_offset, reverse)

	// 绘制entity体积框
	draw_rectangle(
		draw_pos.x,
		draw_pos.y,
		i32(meter_to_pixel(entity.size.x)),
		i32(meter_to_pixel(entity.size.y)),
		RED,
		buffer,
		outline = true,
	)
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

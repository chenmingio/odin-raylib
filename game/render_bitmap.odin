package game

import "base:intrinsics"
import "core:image"
import "core:math"
import "core:slice"

BufferRectangle :: struct {
	min: V2i,
	max: V2i,
}

// 绘制矩形（填充或边框）
draw_rectangle :: proc(
	top_left_pos: V2i, //pixel x-y-pos
	size_px: V2i,
	color: u32,
	buffer: OffScreenBuffer,
	outline: bool = false,
) {
	// 输入矩形
	rect := BufferRectangle {
		min = top_left_pos,
		max = top_left_pos + size_px,
	}

	// buffer 边界
	buffer_rect := BufferRectangle {
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

blend :: proc(target, source: []u32, reverse: bool = false) {
	assert(len(target) == len(source))
	for i in 0 ..< len(target) {
		si := reverse ? len(target) - i - 1 : i

		// 快速路径：全透明/全不透明
		// 注意：source/target 的内部像素格式一致，可直接赋值
		c_src_swapped := intrinsics.byte_swap(source[si])
		as := c_src_swapped & 0xFF
		if as == 0 {
			continue
		}
		if as == 255 {
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
	draw_image_corp(pos, img, buffer, source_rect_size = full_size, reverse = reverse)
}

// 绕 source_anchor_pos 旋转图片，并把该点放在 buffer_anchor_pos。
// base_angle 和 target_angle 都是方向向量；图片默认朝向和目标朝向的差值就是旋转角。
draw_image_rotated :: proc(
	buffer_anchor_pos: V2i,
	img: ^image.Image,
	buffer: OffScreenBuffer,
	source_rect_size: V2i = V2i{},
	source_rect_pos: V2i = V2i{},
	source_anchor_pos: V2i,
	reverse: bool = false,
	base_angle: V2,
	target_angle: V2,
) {
	rect_size := source_rect_size
	if rect_size.x <= 0 || rect_size.y <= 0 {
		rect_size = V2i{i32(img.width), i32(img.height)}
	}

	// buffer 的 Y 轴向下，所以计算方向角时要反转 Y。
	base_heading := math.atan2(-base_angle.y, base_angle.x)
	target_heading := math.atan2(-target_angle.y, target_angle.x)
	rotation := target_heading - base_heading
	sin_rotation := math.sin(rotation)
	cos_rotation := math.cos(rotation)

	// 先将图片四角正向旋转，得到需要扫描的最小 buffer 矩形。
	corners := [4]V2i{{0, 0}, {rect_size.x, 0}, {0, rect_size.y}, {rect_size.x, rect_size.y}}
	min_x, max_x := f32(buffer_anchor_pos.x), f32(buffer_anchor_pos.x)
	min_y, max_y := f32(buffer_anchor_pos.y), f32(buffer_anchor_pos.y)
	for corner in corners {
		dx := f32(corner.x - source_anchor_pos.x)
		dy := f32(corner.y - source_anchor_pos.y)
		x := f32(buffer_anchor_pos.x) + cos_rotation * dx + sin_rotation * dy
		y := f32(buffer_anchor_pos.y) - sin_rotation * dx + cos_rotation * dy
		min_x, max_x = min(min_x, x), max(max_x, x)
		min_y, max_y = min(min_y, y), max(max_y, y)
	}

	draw_min_x := max(i32(0), i32(math.floor(min_x)))
	draw_max_x := min(buffer.width, i32(math.ceil(max_x)))
	draw_min_y := max(i32(0), i32(math.floor(min_y)))
	draw_max_y := min(buffer.height, i32(math.ceil(max_y)))
	pixels := transmute([dynamic]u32)img.pixels.buf
	img_width := i32(img.width)

	for y in draw_min_y ..< draw_max_y {
		for x in draw_min_x ..< draw_max_x {
			// 反向旋转：由 buffer 像素求原图像素，避免正向绘制产生空洞。
			dx := f32(x - buffer_anchor_pos.x)
			dy := f32(y - buffer_anchor_pos.y)
			source_x := i32(
				math.floor(cos_rotation * dx - sin_rotation * dy + f32(source_anchor_pos.x)),
			)
			source_y := i32(
				math.floor(sin_rotation * dx + cos_rotation * dy + f32(source_anchor_pos.y)),
			)
			if source_x < 0 || source_x >= rect_size.x || source_y < 0 || source_y >= rect_size.y {
				continue
			}
			if reverse {
				source_x = rect_size.x - 1 - source_x
			}

			// source_x/source_y 是裁剪区域内的坐标；加上 source_rect_pos 才是整张图的坐标。
			image_x := source_rect_pos.x + source_x
			image_y := source_rect_pos.y + source_y
			if image_x < 0 || image_x >= img_width || image_y < 0 || image_y >= i32(img.height) {
				continue
			}

			source := pixels[image_y * img_width + image_x:image_y * img_width + image_x + 1]
			target := buffer.data[y * buffer.width + x:y * buffer.width + x + 1]
			blend(target, source)
		}
	}
}

// 从图集中裁剪并绘制图像
draw_image_corp :: proc(
	left_top_buffer_pos: V2i,
	img: ^image.Image,
	buffer: OffScreenBuffer,
	source_rect_size: V2i = V2i{},
	source_rect_pos: V2i = V2i{},
	reverse: bool = false,
) {
	sprite_rect := BufferRectangle {
		min = left_top_buffer_pos,
		max = left_top_buffer_pos + source_rect_size,
	}
	buffer_rect := BufferRectangle {
		min = V2i{0, 0},
		max = V2i{buffer.width, buffer.height},
	}

	draw_rect, ok := intersect_rect(sprite_rect, buffer_rect)
	if !ok {
		return
	}

	pixels_u32 := transmute([dynamic]u32)img^.pixels.buf
	img_width := i32(img^.width)

	for ty in draw_rect.min.y ..< draw_rect.max.y {
		sy := ty - left_top_buffer_pos.y + source_rect_pos.y
		sx := draw_rect.min.x - left_top_buffer_pos.x + source_rect_pos.x
		width := draw_rect.max.x - draw_rect.min.x

		src_start := sy * img_width + sx
		source := pixels_u32[src_start:src_start + width]

		dst_start := ty * buffer.width + draw_rect.min.x
		target := buffer.data[dst_start:dst_start + width]

		blend(target, source, reverse)
	}
}

// 两个矩形求交集
intersect_rect :: proc(a, b: BufferRectangle) -> (BufferRectangle, bool) {
	result := BufferRectangle {
		min = V2i{max(a.min.x, b.min.x), max(a.min.y, b.min.y)},
		max = V2i{min(a.max.x, b.max.x), min(a.max.y, b.max.y)},
	}

	ok := result.min.x < result.max.x && result.min.y < result.max.y
	return result, ok
}

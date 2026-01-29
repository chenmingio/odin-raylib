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
// pos: 屏幕目标位置（左上角）
// atlas_offset: 图集中的起始位置
// sprite_size: 要绘制的 sprite 尺寸
draw_image_corp :: proc(
	pos: V2i,
	img: ^image.Image,
	buffer: OffScreenBuffer,
	sprite_size: V2i = V2i{},
	atlas_offset: V2i = V2i{},
	reverse: bool = false,
) {
	assert(atlas_offset.x >= 0 && atlas_offset.y >= 0)

	// 1. 计算实际要绘制的 sprite 尺寸（不超过图集边界）
	draw_width := min(sprite_size.x, i32(img^.width) - atlas_offset.x)
	draw_height := min(sprite_size.y, i32(img^.height) - atlas_offset.y)

	// 2. 屏幕裁剪：计算可见区域
	screen_min_x := clamp(pos.x, 0, buffer.width)
	screen_max_x := clamp(pos.x + draw_width, screen_min_x, buffer.width)
	screen_min_y := clamp(pos.y, 0, buffer.height)
	screen_max_y := clamp(pos.y + draw_height, screen_min_y, buffer.height)

	// 3. 计算被屏幕左/上边缘裁掉的像素数
	clip_left := screen_min_x - pos.x  // pos.x < 0 时为正
	clip_top := screen_min_y - pos.y   // pos.y < 0 时为正

	// 4. 图像读取起始位置 = 图集偏移 + 屏幕裁剪偏移
	src_start_x := atlas_offset.x + clip_left
	src_start_y := atlas_offset.y + clip_top

	// 5. 可见区域的宽高
	visible_width := screen_max_x - screen_min_x
	visible_height := screen_max_y - screen_min_y

	if visible_width <= 0 || visible_height <= 0 {
		return // 完全在屏幕外
	}

	// 预转换像素缓冲
	pixels_u32 := transmute([dynamic]u32)img^.pixels.buf

	// 6. 逐行复制
	for row in 0 ..< visible_height {
		src_row := src_start_y + row
		src_start := src_row * i32(img^.width) + src_start_x
		source := pixels_u32[src_start:src_start + visible_width]

		dst_row := screen_min_y + row
		dst_start := dst_row * buffer.width + screen_min_x
		target := buffer.data[dst_start:dst_start + visible_width]

		blend(target, source, reverse)
	}
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
		true,
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
		true,
	)
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

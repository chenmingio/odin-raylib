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
CYAN := intrinsics.byte_swap(u32(0x00FFFFFF))
YELLOW := intrinsics.byte_swap(u32(0xFFFF00FF))
MAGENTA := intrinsics.byte_swap(u32(0xFF00FFFF))


OffScreenBuffer :: struct {
	data:   []u32,
	width:  i32,
	height: i32,
}

// use buffer pixel pos
draw_entity_body_rectangle :: proc(
	entity_pivot_buffer_pos: V2i,
	size_px: V2i,
	buffer: OffScreenBuffer,
) {
	draw_rectangle(
		entity_top_left_from_pivot(entity_pivot_buffer_pos, size_px),
		size_px,
		RED,
		buffer,
		true,
	)
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
	draw_image_corp(pos, img, buffer, source_rect_size = full_size, reverse = reverse)
}

draw_tile_map :: proc(grid_pos: V2i, tile_idx: V2i, img: ^image.Image, buffer: OffScreenBuffer) {
	tiles_per_col :: 6
	tile_size := i32(img^.height / tiles_per_col)

	// atlas 中 tile 的位置
	source_rect_pos := V2i{tile_idx.x * tile_size, tile_idx.y * tile_size}

	// 屏幕上的位置
	screen_pos := V2i {
		grid_pos.x * tile_size + tile_size / 2,
		grid_pos.y * tile_size + tile_size / 2,
	}

	draw_image_corp(
		screen_pos,
		img,
		buffer,
		source_rect_size = V2i{tile_size, tile_size},
		source_rect_pos = source_rect_pos,
	)
}

// 从图集中裁剪并绘制图像
//
// 概念模型：
//   1. sprite 放在 buffer 的 pos 位置，形成 sprite_rect
//   2. sprite_rect 和 buffer_rect 求交集，得到 draw_rect
//   3. 遍历 draw_rect 的每个点，反推 source 坐标，复制像素
//
draw_image_corp :: proc(
	left_top_buffer_pos: V2i,
	img: ^image.Image,
	buffer: OffScreenBuffer,
	source_rect_size: V2i = V2i{},
	source_rect_pos: V2i = V2i{},
	reverse: bool = false,
) {
	// sprite 在 buffer 上占据的矩形
	sprite_rect := BufferRectangle {
		min = left_top_buffer_pos,
		max = left_top_buffer_pos + source_rect_size,
	}

	// buffer 边界
	buffer_rect := BufferRectangle {
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
		sy := ty - left_top_buffer_pos.y + source_rect_pos.y
		sx := draw_rect.min.x - left_top_buffer_pos.x + source_rect_pos.x

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
intersect_rect :: proc(a, b: BufferRectangle) -> (BufferRectangle, bool) {
	result := BufferRectangle {
		min = V2i{max(a.min.x, b.min.x), max(a.min.y, b.min.y)},
		max = V2i{min(a.max.x, b.max.x), min(a.max.y, b.max.y)},
	}

	// 检查是否有效（有面积）
	ok := result.min.x < result.max.x && result.min.y < result.max.y
	return result, ok
}

// 以屏幕为原点的相对坐标 转换为 buffer的相对像素坐标（左上角为原点，xy倒置）
rel_pos_to_buffer_pos :: proc(rel: V3, buffer: OffScreenBuffer) -> V2i {
	return V2i{buffer.width / 2 + i32(rel.x * SCALE), buffer.height / 2 - i32(rel.y * SCALE)}
}

entity_top_left_from_pivot :: proc(entity_pivot_buffer_pos: V2i, size_px: V2i) -> V2i {
	// 对象左上角 = 屏幕中心 + 相对偏移 - 重心到左上角调整(半宽, 全高)
	return entity_pivot_buffer_pos - V2i{size_px.x / 2, size_px.y}
}

draw_entity_size :: proc(rel_position: V3, size: V2, buffer: OffScreenBuffer) {
	// 把相对位置（单位m）转换成对应屏幕上的位置（pixel）
	rel_pos_px := meter_to_pixel(rel_position)
	rel_px := V2i{i32(rel_pos_px.x), -i32(rel_pos_px.y)} // 上为负??

	// 玩家帧尺寸 or 一般实体尺寸（米→像素）
	size_px := V2i{i32(meter_to_pixel(size.x)), i32(meter_to_pixel(size.y))}

	// 对象左上角 = 屏幕中心 + 相对偏移 - 重心到左上角调整(半宽, 全高)
	screen_center := V2i{buffer.width / 2, buffer.height / 2}
	top_left := screen_center + rel_px - V2i{size_px.x / 2, size_px.y}

}

draw_entity_image :: proc(
	dest_buffer_pos: V2i,
	image: ^image.Image,
	entity: ^LowEntity,
	buffer: OffScreenBuffer,
) {
	size_px := meter_to_pixel(entity.size)
	top_left_pos := dest_buffer_pos - entity.img_pivot_offset

	draw_image_simple(top_left_pos, image, buffer)
	draw_entity_body_rectangle(dest_buffer_pos, size_px, buffer)
}

// 假设动画图片水平排列，一共有frames帧
draw_entity_animation :: proc(
	dest_buffer_pos: V2i,
	animation: Animation,
	entity: ^LowEntity,
	buffer: OffScreenBuffer,
	dt: f32,
) {
	image := animation.image
	status := entity.status
	reverse := entity.direction == Direction.Backward

	// in pixel
	clip_frames := animation.clips[status].frames
	assert(len(clip_frames) > 0)

	entity.anim_time += i32(dt * 1000)
	for entity.anim_time >= clip_frames[entity.anim_frame_idx].duration {
		entity.anim_time -= clip_frames[entity.anim_frame_idx].duration
		entity.anim_frame_idx = (entity.anim_frame_idx + 1) % i32(len(clip_frames))
	}

	anim_frame := clip_frames[entity.anim_frame_idx]
	source_rect_size := V2i{anim_frame.frame.w, anim_frame.frame.h}
	source_rect_pos := V2i{anim_frame.frame.x, anim_frame.frame.y}

	trim_offset_in_source := V2i{anim_frame.spriteSourceSize.x, anim_frame.spriteSourceSize.y}

	pivot_in_source := animation.pivot_in_source
	offset_from_pivot_to_dest := trim_offset_in_source - pivot_in_source
	// reverse通过画图可以发现，是pivot到dest点翻转再减去frame上边框向量构成的新的向量
	if reverse {
		offset_from_pivot_to_dest =
			offset_from_pivot_to_dest * V2i{-1, 1} - V2i{source_rect_size.x, 0}
	}

	// 逻辑：把原始 source frame 里的固定 pivot 对齐到实体 pivot，再画 trimmed sprite。
	// entity_pivot_buffer_pos 基础位置，从哪里开始画，此时sprite的左上角在目标点
	// trim_offset_in_source 从trimmed sprite还原为source frame的左上角
	// pivot_in_source 从source frame左上角到固定pivot点（约定为画面上的人物重心）
	// 向量的方向根据xy的正负和buffer pos的正负方向来确定箭头方向。
	sprite_dest_top_left := dest_buffer_pos + offset_from_pivot_to_dest

	draw_image_corp(
		sprite_dest_top_left,
		image,
		buffer,
		source_rect_size,
		source_rect_pos,
		reverse,
	)
	draw_entity_body_rectangle(dest_buffer_pos, meter_to_pixel(entity.size), buffer)
}

render_sim_region :: proc(
	sim_region: ^SimRegion,
	image_buffer: OffScreenBuffer,
	game_state: ^GameState,
	time_span: f32,
) {

	entities := sim_region.high_entities[:sim_region.high_entity_count]

	for i in 0 ..< len(entities) {
		entity := entities[i].low_entity
		// 下面计算把worldPos（米）转换为buffer使用的坐标（pixel）
		entity_pivot_buffer_pos := rel_pos_to_buffer_pos(
			relative_pos(entity.pos, game_state^.camera_pos),
			image_buffer,
		)

		// 玩家帧尺寸 or 一般实体尺寸（米→像素）
		entity_size_px := V2i {
			i32(meter_to_pixel(entity.size.x)),
			i32(meter_to_pixel(entity.size.y)),
		}
		top_left_buffer_pos := entity_top_left_from_pivot(entity_pivot_buffer_pos, entity_size_px)

		// 是否玩家
		is_player := entity.type == EntityType.Player

		switch entity.type {
		case .Player:
			draw_entity_animation(
				entity_pivot_buffer_pos,
				game_state.unit_animate,
				entity,
				image_buffer,
				time_span,
			)
		case .Wall:
			draw_entity_image(
				entity_pivot_buffer_pos,
				game_state^.rock_images[0],
				entity,
				image_buffer,
			)
		case .Tree:
		case .Enemy:
		case .Null:
			break
		}
	}
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

@(test)
test_image :: proc(t: ^testing.T) {
	img, err := image.load_from_file("resources/background_pink_sky.png")
	if err != nil {
		testing.fail(t)
		return
	}
	image.destroy(img)
}

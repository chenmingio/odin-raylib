package game

import "core:image"

// use buffer pixel pos
draw_entity_body_rectangle :: proc(
	entity_anchor_buffer_pos: V2i,
	size_px: V2i,
	buffer: OffScreenBuffer,
) {
	draw_rectangle(
		entity_top_left_from_anchor(entity_anchor_buffer_pos, size_px),
		size_px,
		RED,
		buffer,
		true,
	)
}

entity_top_left_from_anchor :: proc(entity_anchor_buffer_posanchor: V2i, size_px: V2i) -> V2i {
	// 对象左上角 = 屏幕中心 + 相对偏移 - 重心到左上角调整(半宽, 全高)
	return entity_anchor_buffer_posanchor - V2i{size_px.x / 2, size_px.y}
}

draw_entity_image :: proc(
	dest_buffer_pos: V2i,
	image: ^image.Image,
	entity: ^LowEntity,
	buffer: OffScreenBuffer,
	anchor_offset: V2i,
) {
	size_px := meter_to_pixel(entity.size.xy)
	top_left_pos := dest_buffer_pos - anchor_offset

	draw_image_simple(top_left_pos, image, buffer)
	when ODIN_DEBUG {
		draw_entity_body_rectangle(dest_buffer_pos, size_px, buffer)
	}
}

// 假设动画图片水平排列，一共有frames帧
// 根据entity的status来找到对应行
// 根据entity的anim_time/anim_frame_idx来判断画哪一帧
draw_entity_animation :: proc(
	dest_buffer_pos: V2i,
	animation: Animation,
	entity: ^LowEntity,
	buffer: OffScreenBuffer,
	dt: f32,
) {
	image := animation.image
	reverse := entity.direction == Direction.Backward

	// in pixel
	clip_frames := animation.clips[entity.status].frames
	anim_frame := clip_frames[entity.anim_frame_idx]
	source_rect_size := V2i{anim_frame.frame.w, anim_frame.frame.h}
	source_rect_pos := V2i{anim_frame.frame.x, anim_frame.frame.y}

	trim_offset_in_source := V2i{anim_frame.spriteSourceSize.x, anim_frame.spriteSourceSize.y}

	anchor_in_source := animation.anchor_in_source
	offset_from_anchor_to_dest := trim_offset_in_source - anchor_in_source
	// reverse通过画图可以发现，是anchor到dest点翻转再减去frame上边框向量构成的新的向量
	if reverse {
		offset_from_anchor_to_dest =
			offset_from_anchor_to_dest * V2i{-1, 1} - V2i{source_rect_size.x, 0}
	}

	// 逻辑：把原始 source frame 里的固定 anchor 对齐到实体 anchor，再画 trimmed sprite。
	// entity_anchor_buffer_pos 基础位置，从哪里开始画，此时sprite的左上角在目标点
	// trim_offset_in_source 从trimmed sprite还原为source frame的左上角
	// anchor_in_source 从source frame左上角到固定anchor点（约定为画面上的人物重心）
	// 向量的方向根据xy的正负和buffer pos的正负方向来确定箭头方向。
	sprite_dest_top_left := dest_buffer_pos + offset_from_anchor_to_dest

	draw_image_corp(
		sprite_dest_top_left,
		image,
		buffer,
		source_rect_size,
		source_rect_pos,
		reverse,
	)

	when ODIN_DEBUG {
		draw_entity_body_rectangle(dest_buffer_pos, meter_to_pixel(entity.size.xy), buffer)
	}
}

// 武器需要处理
// 1.旋转角度：entity的v
// 2.旋转中心：sprite的anchor
draw_sprite :: proc(
	dest_buffer_pos: V2i,
	sprite: Sprite,
	entity: ^LowEntity,
	buffer: OffScreenBuffer,
	dt: f32,
) {
	top_left_pos := dest_buffer_pos
	z_scale :: 1
	screen_velocity := V2{entity.dp.x, -(entity.dp.y + entity.dp.z * z_scale)}
	draw_image_rotated(
		top_left_pos,
		sprite.image,
		buffer,
		sprite.frame_size,
		sprite.frame_pos,
		sprite.anchor_in_frame,
		false,
		V2{1, -1},
		screen_velocity,
	)

	when ODIN_DEBUG {
		draw_entity_body_rectangle(dest_buffer_pos, meter_to_pixel(entity.size.xy), buffer)
	}
}

draw_entity_hit_point :: proc(
	anchor: V2i,
	size: V2i,
	buffer: OffScreenBuffer,
	total_points: i32,
	left_points: i32,
) {
	space_px :: 10
	point_size_px :: 10
	left_anchor_offset_x := i32(
		(total_points - 1) / 2 * space_px + (total_points / 2) * point_size_px,
	)
	for i in 0 ..< total_points {
		draw_rectangle(
			anchor +
			V2i{-left_anchor_offset_x + i * (point_size_px + space_px), -size.y - space_px},
			point_size_px,
			RED,
			buffer,
			!(i < left_points),
		)
	}
}

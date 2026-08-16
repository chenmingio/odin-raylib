package game

import "base:intrinsics"

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

// 以屏幕为原点的相对坐标 转换为 buffer的相对像素坐标（左上角为原点，xy倒置, z按比例兑换为y）
rel_pos_to_buffer_pos :: proc(rel: V3, buffer: OffScreenBuffer) -> V2i {
	return V2i {
		buffer.width / 2 + i32(rel.x * PIXELS_PER_METER),
		buffer.height / 2 - i32(rel.y * PIXELS_PER_METER) - i32(rel.z * PIXELS_PER_METER),
	}
}

render_sim_region :: proc(
	sim_region: ^SimRegion,
	image_buffer: OffScreenBuffer,
	state: ^GameState,
	dt: f32,
) {
	camera_bound_rel := V3{CAMERA_VIEW_SPAN_X_IN_METERS, CAMERA_VIEW_SPAN_Y_IN_METERS, 0} / 2

	camera_bounds_min := world_pos_minus(state.world, state.camera_p, camera_bound_rel)
	camera_bounds_max := world_pos_add(state.world, state.camera_p, camera_bound_rel)

	for x in camera_bounds_min.chunkXYZ.x ..= camera_bounds_max.chunkXYZ.x {
		for y in camera_bounds_min.chunkXYZ.y ..= camera_bounds_max.chunkXYZ.y {
			chunk := get_world_chunk(state.world, V3i{x, y, 0}, nil)
			assert(chunk != nil)
			draw_chunk_tile_map(chunk, state, image_buffer)
		}
	}

	entities := sim_region.entities[:sim_region.entity_count]

	for i in 0 ..< len(entities) {
		entity := entities[i].low_entity

		if entity.non_spatial {continue}

		// 下面计算把worldPos（米）转换为buffer使用的坐标（pixel）
		entity_anchor_buffer_pos := rel_pos_to_buffer_pos(entities[i].p, image_buffer)

		// 玩家帧尺寸 or 一般实体尺寸（米→像素）
		entity_size_px := V2i {
			i32(meter_to_pixel(entity.size.x)),
			i32(meter_to_pixel(entity.size.y)),
		}

		switch entity.type {
		case .Player:
			draw_entity_animation(
				entity_anchor_buffer_pos,
				state.unit_animate,
				entity,
				image_buffer,
				dt,
			)
			draw_entity_hit_point(
				entity_anchor_buffer_pos,
				entity_size_px,
				image_buffer,
				entity.hit_point_total,
				entity.hit_point_left,
			)
		case .Wall:
			draw_entity_image(
				entity_anchor_buffer_pos,
				state^.rock_images[0],
				entity,
				image_buffer,
				V2i{32, 48},
			)
		case .Tree, .Tile:
		case .Enemy:
			draw_entity_animation(
				entity_anchor_buffer_pos,
				state.harpoon_shark_animation,
				entity,
				image_buffer,
				dt,
			)
		case .Weapon:
			draw_sprite(entity_anchor_buffer_pos, state.harpoon_sprite, entity, image_buffer, dt)
		case .Null:
			break
		}
	}
}

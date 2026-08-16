package game

import "core:math/linalg"

SimRegion :: struct {
	entities:            [4096]SimEntity, // 复制数据（而不是id或者指针），方便模拟和修改
	entity_count:        u32,
	debug_collision:     CollisionDebug,
	max_entity_radius:   f32,
	max_entity_velocity: f32,
}

// 加载相关entity到high区
begin_sim :: proc(state: ^GameState, memory: ^Memory, dt: f32) -> SimRegion {
	// TODO: 目前entity.p在camera-bound才算updatable。
	// 但是最好是entity collison volume和camera-bound相交就算updatable（实时为每个entity计算）
	//
	result := SimRegion {
		max_entity_radius   = 5,
		max_entity_velocity = 30,
	}

	// 位于camera边缘的entity以最快速度达到的边缘
	margin_radius := result.max_entity_radius * 2 + result.max_entity_velocity * dt

	camera_bound_rel := V3 {
		CAMERA_VIEW_SPAN_X_IN_METERS,
		CAMERA_VIEW_SPAN_Y_IN_METERS,
		CAMERA_VIEW_SPAN_Z_IN_METERS,
	} / 2

	camera_bounds_min := world_pos_minus(state.world, state.camera_p, camera_bound_rel)
	camera_bounds_max := world_pos_add(state.world, state.camera_p, camera_bound_rel)
	camera_bounds := Box{-camera_bound_rel, camera_bound_rel}
	bounds_min := world_pos_minus(state.world, camera_bounds_min, margin_radius)
	bounds_max := world_pos_add(state.world, camera_bounds_max, margin_radius)

	for x in bounds_min.chunkXYZ.x ..= bounds_max.chunkXYZ.x {
		for y in bounds_min.chunkXYZ.y ..= bounds_max.chunkXYZ.y {
			for z in bounds_min.chunkXYZ.z ..= bounds_max.chunkXYZ.z {

				chunk := get_world_chunk(state.world, V3i{x, y, z}, memory)
				assert(chunk != nil)

				// refer low_entity into SimRegion, later change to copy value
				for block := chunk.first_block; block != nil; block = block.next {
					for low_entity_storage_id in block.entity_indexes[:block.entity_count] {
						low_entity := &state.low_entities[low_entity_storage_id]
						p := relative_pos(state.world, low_entity.pos, state.camera_p)

						p_in_camera_bound := overlap_box(
							camera_bounds,
							entity_size_box(low_entity.size, p),
						)


						high_entity := SimEntity {
							low_entity    = low_entity,
							storage_index = low_entity_storage_id,
							p             = p,
							updatable     = p_in_camera_bound,
						}

						assert(result.entity_count < len(result.entities))
						result.entities[result.entity_count] = high_entity
						result.entity_count += 1
					}
				}
			}
		}
	}
	return result
}


simulate :: proc(sim_region: ^SimRegion, dt: f32, game_state: ^GameState, game_memory: ^Memory) {
	entities := sim_region.entities[:sim_region.entity_count]

	// 不需要同步模拟(也就是不需要使用相对速度/加速度）
	// a物体运动好以后，b物体在a物体移动后的状态下继续算他的运动。
	// 不是很严谨（最后状态与ety loop次序有关），但是对于RPG这类游戏足够（kinematic mover）
	for &e_a in entities {
		// 只有运动的物体才会碰撞改变位置，不需要对墙体做运动判断。
		if e_a.low_entity.moveable && e_a.updatable {
			// other是不动的。即使他是个怪物，被碰撞时，也需要保持不动。
			// 如果是怪物碰hero，可能hero被卡住了。所以可以在shouldCollide里控制。

			// 使用time remaining还是delta remaining来计算？
			// 算法使用近似思路
			// 0.想象一个物体本来做直线运动，碰撞以后，继续滑动，距离和碰撞坡度相关
			// 1.因为t很小，acc一般也小，简化为：以加速度结束后的尾速度作匀速直线运动
			// 2.尾速度为v1，位移为dp（理论上为曲线，近似为直线线段）
			// 3.总的dp不变（视觉上撞击后移动的投影路径长度近似不变）
			// 因此不能用time来做不变量（虽然长度和速度计算简化为匀速运动，但时间可能不是）
			// 因为不能用time和v中间的来做计算匀速运动计算（反而减少了变量），所以直接用碰撞点的长度与dp的长度的投影做比例，计算剩余的dp
			//
			// v0 = 当前速度
			// a  = 当前加速度
			// dt = 本帧时长
			// v1    = v0 + a * dt

			// 如果没有碰撞，运行的距离
			// delta = v0 * dt + 0.5 * a * dt * dt
			dp_remaining := e_a.low_entity.dp * dt + 0.5 * e_a.low_entity.ddp * dt * dt
			e_a.low_entity.dp = e_a.low_entity.dp + e_a.low_entity.ddp * dt

			// z 方向单独处理，不参与碰撞
			e_a.p.z += dp_remaining.z
			dp_remaining.z = 0

			for n in 0 ..< 4 {

				nearest_hit := HitResult {
					sweep_fraction = 1,
				}
				// 先找到最近的碰撞对象nearest_hit，计算碰撞结果
				for &e_b in entities {
					// check-point-1: 有些不碰撞，比如玩家和他的武器
					if can_collide(&e_a, &e_b, game_state) {
						hit_result := collide_minkowski_swept_AABB(&e_a, &e_b, dp_remaining.xy)
						if hit_result.hit &&
						   (hit_result.sweep_fraction < nearest_hit.sweep_fraction) {
							hit_result.other = &e_b
							nearest_hit = hit_result
						}
					}
				}

				if nearest_hit.hit {
					// debug显示碰撞箱
					record_collision_debug(
						&sim_region.debug_collision,
						&e_a,
						nearest_hit.other,
						dp_remaining.xy,
						nearest_hit,
					)
					// check-point-2: 碰撞以后有些特殊逻辑。
					// 因为是loop循环系统，有些逻辑可以通过修改check-point-1的碰撞逻辑解决handle-collison的问题
					// 比如碰撞过一次以后就不扣血了，但是可以变成碰撞过一次以后就不碰撞了（也不扣血了）
					stop_on_collison := handle_collision(
						&e_a,
						nearest_hit.other,
						game_state,
						game_memory,
					)
					if stop_on_collison {
						dp := dp_remaining * nearest_hit.sweep_fraction
						e_a.p += dp

						dp_remaining_xy :=
							linalg.dot(
								dp_remaining.xy * (1 - nearest_hit.sweep_fraction),
								nearest_hit.surface.xy,
							) *
							nearest_hit.surface.xy
						dp_remaining.xy = dp_remaining_xy

						e_a.low_entity.dp.xy = linalg.dot(
							e_a.low_entity.dp.xy,
							nearest_hit.surface,
						)
					} else {
						// 没有碰撞
						dp := dp_remaining
						e_a.p += dp
						break
					}
				} else {
					// 没有碰撞
					dp := dp_remaining
					e_a.p += dp
					break
				}
			}
		}
	}
}

// 把计算好的high entity对应的状态（目前是未知）更新回原来的low entity
end_sim :: proc(state: ^GameState, sim_region: ^SimRegion, memory: ^Memory) {
	high_entities := sim_region.entities[:sim_region.entity_count]
	for high_entity in high_entities {
		low_entity := high_entity.low_entity
		new_pos := map_into_chunk_space(state.world, high_entity.p, state.camera_p)
		old_pos := low_entity.pos

		// 武器命中以后需要回收重置
		if low_entity.type == EntityType.Weapon && low_entity.flight_time_remaining <= 0 {
			low_entity.non_spatial = true
			clear_collision_rules_for(high_entity.storage_index, state)
		}
		// 调整entity在chunk hash里的位置
		change_entity_location(
			low_entity,
			high_entity.storage_index,
			new_pos,
			state,
			memory,
			low_entity.non_spatial,
		)

		// 对于需要真正删除的entity，还需要从entity list里移除
		//remove_entity_from_entity_list(state, high_entity.low_entity_storage_index)
		low_entity.pos = new_pos

	}
}

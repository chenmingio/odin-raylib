package game

import "core:crypto/blake2b"
import "core:fmt"
import "core:math"
import "core:math/linalg"

SimRegion :: struct {
	entities:            [4096]SimEntity, // 复制数据（而不是id或者指针），方便模拟和修改
	entity_count:        u32,
	space:               BufferRectangle,
	debug_collision:     CollisionDebug,
	max_entity_radius:   f32,
	max_entity_velocity: f32,
}

// 只用于画出最近一次 sweep 命中的计算过程；所有坐标都仍在 sim 的相对世界坐标中。
CollisionDebug :: struct {
	valid:              bool,
	expanded_min:       V2,
	expanded_max:       V2,
	relative_ray_start: V2,
	relative_ray_end:   V2,
	actual_path_start:  V2,
	actual_path_end:    V2,
	hit_point:          V2,
}

HalfPlane :: struct {
	n: V2,
	c: f32, // inside: dot(n, x) <= c
}

Interval :: struct {
	min:   f32,
	max:   f32,
	valid: bool,
}

SIM_EPS :: math.F32_EPSILON

// 加载相关entity到high区
begin_sim :: proc(state: ^GameState, memory: ^Memory, dt: f32) -> SimRegion {
	result := SimRegion {
		max_entity_radius   = 5,
		max_entity_velocity = 30,
	}

	margin_radius := result.max_entity_radius + result.max_entity_velocity * dt

	Tile_Span_X :: 17 * 3 * 1.4
	Tile_Span_Y :: 9 * 3 * 1.4
	Tile_Span_Z :: 3 * 1.4

	camera_bound_rel := V3{Tile_Span_X, Tile_Span_Y, Tile_Span_Z} / 2

	camera_bounds_min := world_pos_minus(state.world, state.camera_p, camera_bound_rel)
	camera_bounds_max := world_pos_add(state.world, state.camera_p, camera_bound_rel)
	marginal_bounds_min := world_pos_minus(state.world, camera_bounds_min, margin_radius)
	marginal_bounds_max := world_pos_add(state.world, camera_bounds_max, margin_radius)

	for x in marginal_bounds_min.chunkXYZ.x ..= marginal_bounds_max.chunkXYZ.x {
		for y in marginal_bounds_min.chunkXYZ.y ..= marginal_bounds_max.chunkXYZ.y {
			for z in marginal_bounds_min.chunkXYZ.z ..= marginal_bounds_max.chunkXYZ.z {

				chunk := get_world_chunk(state.world, V3i{x, y, z}, memory)
				assert(chunk != nil)

				// refer low_entity into SimRegion, later change to copy value
				for block := chunk.first_block; block != nil; block = block.next {
					for low_entity_storage_id in block.entity_indexes[:block.entity_count] {
						low_entity := &state.low_entities[low_entity_storage_id]
						p := relative_pos(state.world, low_entity.pos, state.camera_p)

						p_in_camera_bound :=
							p.x <= camera_bound_rel.x &&
							p.y <= camera_bound_rel.y &&
							p.z <= camera_bound_rel.z

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


high_entity_rect_center :: proc(h_e: ^SimEntity) -> V2 {
	result := h_e.p
	result.y = result.y + h_e.low_entity.size.y / 2
	return V2{result.x, result.y}
}


// 从多边形的两个连续的点（逆时针），算出从原点到线上的垂直向量。这个向量用来表征一个半平面。
// x dot v = |v|时，在线上。
// x dot v > |v|时，在平面内。
// x dot v < |v|时，在平面外。
// 这个半平面就是两点组成直线且靠多边形内部的半平面
// 他和另外一个向量的点积，如果超过他的长度，就是在半平面内部。如果相等就是在直线上。
half_plane_from_ccw_points :: proc(a: V2, b: V2) -> HalfPlane {
	d := b - a
	// 找一个逆时针法线方向的向量
	n := linalg.orthogonal(d)
	c := linalg.dot(a, n)
	return HalfPlane{n, c}
}

// 对于初始点在o,速度为v的移动点 x(t) = o + v*t
// 在平面内 => x(t) · n >= c
// => o · n + t (n · v) >= c
// => t (n · v) + (o · n - c) >= 0
// => sv * t + s0 >=0
// sv:(n · v) 位移在法线n上的投影（乘以固定n的长度）
// s0:(o · n - c) 起始点和半平面的关系。s0 > 0, o在平面内
// 移动的向量 在平面内 => sv * t >= -s0
// t=0时， 0 >= -s0 => 判断起点是不是在平面内
dt_in_half_plane :: proc(o: V2, v: V2, hp: HalfPlane) -> Interval {
	neg_inf := math.inf_f32(-1)
	pos_inf := math.inf_f32(+1)

	sv := linalg.dot(hp.n, v)
	s0 := linalg.dot(hp.n, o) - hp.c
	if sv > SIM_EPS {
		// t >= -s0 / sv
		return Interval{s0 * (-1) / sv, pos_inf, true}
	} else if sv < SIM_EPS {
		// t <= -s0 / sv
		return Interval{neg_inf, s0 * (-1) / sv, true}
	} else { 	// sv = 0
		// 0 >= -s0?
		// => s0 >= 0?
		// => o · n >= c?
		if (s0 >= SIM_EPS) {
			return Interval{neg_inf, pos_inf, true}
		} else {
			return Interval{0, 0, false}
		}
	}
}

intersect_interval :: proc(a: Interval, b: Interval) -> Interval {
	if !a.valid || !a.valid {
		return Interval{0, 0, false}
	} else {
		i := V2{max(a.min, b.min), min(a.max, b.max)}
		if (i.x <= i.y) {
			return Interval{i.x, i.y, true}
		} else {
			return Interval{0, 0, false}
		}
	}
}

collide_convex_polygon_swept :: proc(ety_a: ^SimEntity, ety_b: ^SimEntity, time: f32) {
	rel_velocity := ety_a.low_entity.dp - ety_b.low_entity.dp
	// 画出minkowski对应的碰撞体积
	// 把原点放在B的中心，原点 in (A-B)?
	// A - B = A + B（矩形在原点上反转不变） = 以A为中心外面加1/2B的扩大矩形
	c_a := high_entity_rect_center(ety_a)
	c_b := high_entity_rect_center(ety_b)
	// B为原点，A是A-B
	pos_A := c_a - c_b
	extented_A_half := (ety_a.low_entity.size + ety_b.low_entity.size) / 2
	extented_A := Rectangle{c_a - extented_A_half, c_a + extented_A_half}
	min := extented_A.min
	max := extented_A.max
	ccw_corners := [4]V2{min, V2{max.x, min.y}, max, V2{min.x, max.y}}

	dts := [4]Interval{}
	for i in 0 ..< len(ccw_corners) {
		from := ccw_corners[i]
		to := ccw_corners[(i + 1) % len(ccw_corners)]
		hp := half_plane_from_ccw_points(from, to)
		dts[i] = dt_in_half_plane(V2{0, 0}, rel_velocity.xy, hp)
	}

	inside_span := Interval{0, time, true}
	for i in 0 ..< len(dts) {
		inside_span = intersect_interval(inside_span, dts[i])
	}

	if inside_span.valid {
		ety_a_new_pos := ety_a.low_entity.dp * inside_span.min
		ety_a.p.x += ety_a_new_pos.x
		ety_a.p.y += ety_a_new_pos.y

		ety_b_new_pos := ety_b.low_entity.dp * inside_span.min
		ety_b.p.x += ety_b_new_pos.x
		ety_b.p.y += ety_b_new_pos.y
	}
}

WallSide :: struct {
	dirction:     V2,
	norm_outside: V2,
	axis_pos:     f32, // x or y value
	wall_scope:   V2, // wall min/max
}

HitResult :: struct {
	hit:            bool,
	other:          ^SimEntity,
	surface:        V2,
	sweep_fraction: f32,
}

record_collision_debug :: proc(
	debug: ^CollisionDebug,
	ety_a, ety_b: ^SimEntity,
	dp_remaining: V2,
	hit: HitResult,
) {
	c_a := high_entity_rect_center(ety_a)
	c_b := high_entity_rect_center(ety_b)
	half := (ety_a.low_entity.size + ety_b.low_entity.size) / 2
	relative_ray := -dp_remaining

	debug^ = CollisionDebug {
		valid              = true,
		expanded_min       = c_a - half,
		expanded_max       = c_a + half,
		relative_ray_start = c_b,
		relative_ray_end   = c_b + relative_ray,
		actual_path_start  = c_a,
		actual_path_end    = c_a + dp_remaining,
		hit_point          = c_b + relative_ray * hit.sweep_fraction,
	}
}


// TODO 现在的回退策略不是很好。需要更好的方法解决float导致的突然卡在边缘/内部的问题。
// 返回碰撞模拟结果，但不能直接修改entity的状态，因为要与所有可能碰撞的entity的碰撞计算选取最近的
collide_minkowski_swept_AABB :: proc(
	ety_a: ^SimEntity,
	ety_b: ^SimEntity,
	dp_remaining: V2,
) -> HitResult {
	// 画出minkowski对应的碰撞体积
	// 把原点放在B的中心，判断原点是否在 in (A-B)?
	// A - B = A + B（矩形在原点上反转不变） = 以A为中心外面加1/2B的扩大矩形
	c_a := high_entity_rect_center(ety_a)
	c_b := high_entity_rect_center(ety_b)
	// B为原点，A是A-B
	pos_A := c_a - c_b
	// B是点，A是体积，以B的中心运动速度为视角,A静止不动
	// 简化算法，other的速度为0

	// 使用位移dp代替速度。因为简化算法基于位移不变，而不是速度，更不是时间
	ray := -dp_remaining

	extented_A_half := (ety_a.low_entity.size + ety_b.low_entity.size) / 2
	extented_A := Rectangle{pos_A - extented_A_half, pos_A + extented_A_half}
	min := extented_A.min
	max := extented_A.max

	wall_sides := [4]WallSide {
		WallSide{V2{1, 0}, V2{0, 1}, max.y, V2{min.x, max.x}}, // 上，y = max_y 水平线
		WallSide{V2{1, 0}, V2{0, -1}, min.y, V2{min.x, max.x}}, // 下，y = min_y 水平线
		WallSide{V2{0, 1}, V2{-1, 0}, min.x, V2{min.y, max.y}}, // 左，x = min_x 垂线
		WallSide{V2{0, 1}, V2{1, 0}, max.x, V2{min.y, max.y}}, // 右，x = max_x 垂线
	}

	// 如果没有碰撞，将使用100%的位移。碰撞则是最短的位移比例
	nearest_hit := HitResult {
		sweep_fraction = 1,
		other          = ety_b,
	}

	for side in wall_sides {
		sweep_fraction: f32
		the_other_axis_value: f32
		surface := side.dirction
		// y=Cy 水平线 y固定，检查x
		if (side.dirction == V2{1, 0}) {
			if math.abs(ray.y) < SIM_EPS {continue} 	// 射线和wall都是水平线，不相交
			sweep_fraction = side.axis_pos / ray.y //投影到y轴，y=Cy时碰撞
			the_other_axis_value = ray.x * sweep_fraction // x的
		} else {
			// x = Cx 垂线 x固定，检查y
			if math.abs(ray.x) < SIM_EPS {continue} 	// 射线和wall都是垂线，不相交
			sweep_fraction = side.axis_pos / ray.x //投影到x轴，x=Cx时碰撞
			the_other_axis_value = ray.y * sweep_fraction
		}

		// 判断方向指向内部。不然贴边的时候，会被卡住无法离开。
		if linalg.dot(ray, side.norm_outside) < 0 &&
		   sweep_fraction >= 0 &&
		   sweep_fraction <= 1 &&
		   the_other_axis_value >= side.wall_scope.x &&
		   the_other_axis_value <= side.wall_scope.y &&
		   sweep_fraction < nearest_hit.sweep_fraction { 	//运动轨迹与x/y线相交叉的位置在边的范围里

			nearest_hit.hit = true
			nearest_hit.sweep_fraction = math.max(sweep_fraction - 0.001, 0)
			nearest_hit.surface = surface
		}
	}
	return nearest_hit
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

// general rule + pairwise rule
// general rules:
// pairwise-based-rules:
// 0. 默认为true
// 1. 武器和owner记录下来为false，不会碰撞（这条可以转化为owner check）
// 2. 伤害过一次就记录下来为false，下次不会重复碰撞
//
can_collide :: proc(ety_a: ^SimEntity, ety_b: ^SimEntity, state: ^GameState) -> bool {
	if (ety_a == ety_b) {
		return false
	}

	rule := get_collision_rule(ety_a.storage_index, ety_b.storage_index, state)
	if rule != nil {
		return rule.can_collide
	} else {
		return true
	}
}

// 目前返回stop_on_collison。但其实可以返回多个碰撞后的信息/event（是否停止？是否受伤？等等）
handle_collision :: proc(
	e_a: ^SimEntity,
	e_b: ^SimEntity,
	state: ^GameState,
	memory: ^Memory,
) -> bool {
	// 碰撞事件处理
	// pairwise-based-rule-2:不能重复碰撞
	weapon_vs_player :=
		(e_a.low_entity.type == EntityType.Weapon && e_b.low_entity.type == EntityType.Player) ||
		(e_b.low_entity.type == EntityType.Weapon && e_a.low_entity.type == EntityType.Player)
	if (weapon_vs_player) {
		weapon := (e_a.low_entity.type == EntityType.Weapon) ? e_a : e_b
		player := (e_a.low_entity.type == EntityType.Player) ? e_a : e_b

		player.low_entity.hit_point_left -= 1
		add_collision_rule(weapon.storage_index, player.storage_index, false, state, memory)
		// 武器和人物碰撞后不停止
		return false
	}
	// 默认停止
	return true
}

// 模拟的浮点坐标转换为low entity的低精度坐标
map_into_chunk_space :: proc(
	world: ^World,
	rel_pos: [3]f32,
	camera_pos: WorldPosition,
) -> WorldPosition {
	result := camera_pos
	result.offset.x += rel_pos.x
	result.offset.y += rel_pos.y
	result.offset.z += rel_pos.z

	return canonicalize(world, result)
}

// 重新放置low entity的chunk位置
change_entity_location :: proc(
	low_entity: ^LowEntity,
	low_entity_storage_index: u32,
	new_pos: WorldPosition,
	state: ^GameState,
	memory: ^Memory,
	remove: bool,
) {
	oldPos := low_entity.pos
	old_chunk := get_world_chunk(state.world, oldPos.chunkXYZ, memory)
	assert(old_chunk != nil)

	if (remove) {
		remove_entity_index_from_hash_chunk(low_entity_storage_index, old_chunk, state)
		return
	}

	// 同一个chunk里不用变
	if (low_entity.pos.chunkXYZ == new_pos.chunkXYZ) {
		return
	}

	remove_entity_index_from_hash_chunk(low_entity_storage_index, old_chunk, state)
	add_entity_index_to_hash_chunk(state, memory, low_entity_storage_index, new_pos.chunkXYZ)
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

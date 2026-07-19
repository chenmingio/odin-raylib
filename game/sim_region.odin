package game

import "core:crypto/blake2b"
import "core:fmt"
import "core:math"
import "core:math/linalg"

SimRegion :: struct {
	high_entities:     [4096]HighEntity, // 复制数据（而不是id或者指针），方便模拟和修改
	high_entity_count: u32,
	space:             BufferRectangle,
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

// 加载相关entity到high区
begin_sim :: proc(state: ^GameState, memory: ^Memory) -> SimRegion {
	result := SimRegion{}
	// 根据camera的坐标找到chunk
	for x in state.camera_pos.chunkXYZ.x - 10 ..< state.camera_pos.chunkXYZ.x + 10 {
		for y in state.camera_pos.chunkXYZ.y - 5 ..< state.camera_pos.chunkXYZ.y + 5 {
			for z in state.camera_pos.chunkXYZ.z ..< state.camera_pos.chunkXYZ.z + 1 {
				chunk := get_world_chunk(state, V3i{x, y, z}, memory)
				assert(chunk != nil)

				// copy entity values into SimRegion
				for block := chunk.first_block; block != nil; block = block.next {
					for low_entity_storage_id in block.entity_indexes[:block.entity_count] {
						low_entity := &state.entities[low_entity_storage_id]
						high_entity := HighEntity {
							low_entity               = low_entity,
							low_entity_storage_index = low_entity_storage_id,
							rel_pos                  = relative_pos(
								low_entity.pos,
								state.camera_pos,
							),
						}
						assert(result.high_entity_count < len(result.high_entities))
						result.high_entities[result.high_entity_count] = high_entity
						result.high_entity_count += 1
					}
				}
			}
		}
	}
	return result
}

shouldCollide :: proc(ety_a: ^HighEntity, ety_b: ^HighEntity) -> bool {
	return ety_a != ety_b
}

drawCollideBody :: proc(_: HighEntity) {

}

high_entity_rect_center :: proc(h_e: ^HighEntity) -> V2 {
	result := h_e.rel_pos
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
time_span_in_half_plane :: proc(o: V2, v: V2, hp: HalfPlane) -> Interval {
	eps: f32 = 1e-6
	neg_inf := math.inf_f32(-1)
	pos_inf := math.inf_f32(+1)

	sv := linalg.dot(hp.n, v)
	s0 := linalg.dot(hp.n, o) - hp.c
	if sv > eps {
		// t >= -s0 / sv
		return Interval{s0 * (-1) / sv, pos_inf, true}
	} else if sv < eps {
		// t <= -s0 / sv
		return Interval{neg_inf, s0 * (-1) / sv, true}
	} else { 	// sv = 0
		// 0 >= -s0?
		// => s0 >= 0?
		// => o · n >= c?
		if (s0 >= eps) {
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

collide_convex_polygon_swept :: proc(ety_a: ^HighEntity, ety_b: ^HighEntity, time: f32) {
	rel_velocity := ety_a.low_entity.velocity - ety_b.low_entity.velocity
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

	time_spans := [4]Interval{}
	for i in 0 ..< len(ccw_corners) {
		from := ccw_corners[i]
		to := ccw_corners[(i + 1) % len(ccw_corners)]
		hp := half_plane_from_ccw_points(from, to)
		time_spans[i] = time_span_in_half_plane(V2{0, 0}, rel_velocity, hp)
	}

	inside_span := Interval{0, time, true}
	for i in 0 ..< len(time_spans) {
		inside_span = intersect_interval(inside_span, time_spans[i])
	}

	if inside_span.valid {
		ety_a_new_pos := ety_a.low_entity.velocity * inside_span.min
		ety_a.rel_pos.x += ety_a_new_pos.x
		ety_a.rel_pos.y += ety_a_new_pos.y

		ety_b_new_pos := ety_b.low_entity.velocity * inside_span.min
		ety_b.rel_pos.x += ety_b_new_pos.x
		ety_b.rel_pos.y += ety_b_new_pos.y
	}
}

WallSide :: struct {
	dirction:   V2,
	axis_pos:   f32, // x or y value
	wall_scope: V2, // wall min/max
}

HitResult :: struct {
	hit:            bool,
	surface:        V2,
	sweep_fraction: f32,
}


// 返回碰撞模拟结果，但不能直接修改entity的状态，因为要与所有可能碰撞的entity的碰撞计算选取最近的
collide_minkowski_swept_AABB :: proc(
	ety_a: ^HighEntity,
	ety_b: ^HighEntity,
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
	rel_velocity := 0 - ety_a.low_entity.velocity
	extented_A_half := (ety_a.low_entity.size + ety_b.low_entity.size) / 2
	extented_A := Rectangle{c_a - extented_A_half, c_a + extented_A_half}
	min := extented_A.min
	max := extented_A.max

	wall_sides := [4]WallSide {
		WallSide{V2{1, 0}, min.y, V2{min.x, max.x}}, // y = min_y 水平线
		WallSide{V2{1, 0}, max.y, V2{min.x, max.x}}, // y = max_y 水平线
		WallSide{V2{0, 1}, min.x, V2{min.y, max.y}}, // x = min_x 垂线
		WallSide{V2{0, 1}, max.x, V2{min.y, max.y}}, // x = max_x 垂线
	}

	eps: f32 = 0.00001
	// 如果没有碰撞，将使用100%的位移。碰撞则是最短的位移比例
	result := HitResult {
		sweep_fraction = 1,
	}

	for side in wall_sides {
		sweep_fraction: f32
		the_other_axis_value: f32
		// y=Cy 水平线 y固定，检查x
		if (side.dirction == V2{1, 0}) {
			the_other_axis_value = rel_velocity.y / rel_velocity.x * side.axis_pos // x的
			sweep_fraction = the_other_axis_value / dp_remaining.x //投影到y轴，y=Cy时碰撞
		} else {
			// x = Cx 垂线 x固定，检查y
			the_other_axis_value = rel_velocity.x / rel_velocity.y * side.axis_pos
			sweep_fraction = the_other_axis_value / dp_remaining.y //投影到x轴，x=Cx时碰撞
		}

		// 运动轨迹与x/y线相交叉的位置在边的范围里
		if the_other_axis_value >= side.wall_scope.x && the_other_axis_value <= side.wall_scope.y {
			// 但只有最短的时间才是碰撞点。暂时不用eps，因为eps的情况应该再外面就被guard掉
			if (sweep_fraction < result.sweep_fraction) {
				result.hit = true
				result.sweep_fraction = sweep_fraction
			}
		}
	}

	return result
}

acc_with_fiction_acc :: proc(ety: ^HighEntity) -> V2 {
	return ety.low_entity.acc + (-0.5 * ety.low_entity.velocity)
}

simulate :: proc(sim_region: ^SimRegion, dt: f32) {
	entities := sim_region.high_entities[:sim_region.high_entity_count]

	// 不需要同步模拟(也就是不需要使用相对速度/加速度）
	// a物体运动好以后，b物体在a物体移动后的状态下继续算他的运动。
	// 不是很严谨（最后状态与ety loop次序有关），但是对于RPG这类游戏足够（kinematic mover）
	for &ety in entities {
		// 只有运动的物体才会碰撞改变位置，不需要对墙体做运动判断。
		if ety.low_entity.moveable {
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

			// 如果没有碰撞运行的距离
			// delta = v0 * dt + 0.5 * a * dt * dt
			dp_max := ety.low_entity.velocity * dt + 0.5 * ety.low_entity.acc * dt * dt
			dp_remaining := dp_max

			for n in 0 ..< 4 {

				hit_result: HitResult
				// 先找到最近的碰撞对象，计算碰撞结果
				for &other in entities {
					if shouldCollide(&ety, &other) {
						hit_result := collide_minkowski_swept_AABB(&ety, &other, dp_remaining)
						if hit_result.hit &&
						   (hit_result.sweep_fraction < hit_result.sweep_fraction) {
							hit_result = hit_result
						}
					}
				}

				time_used: f32
				if hit_result.hit {
					dp := dp_remaining * (1 - hit_result.sweep_fraction)
					ety.rel_pos.x += dp.x
					ety.rel_pos.y += dp.y

					dp_remaining = linalg.dot(dp, hit_result.surface)
					ety.low_entity.velocity = linalg.dot(
						ety.low_entity.velocity,
						hit_result.surface,
					)
				} else {
					// 没有碰撞
					dp := dp_remaining
					ety.rel_pos.x += dp.x
					ety.rel_pos.y += dp.y
					break
				}
			}
		}
	}
}

// 模拟的浮点坐标转换为low entity的低精度坐标
world_pos_add_rel :: proc(rel_pos: [3]f32, camera_pos: WorldPosition) -> WorldPosition {
	result := camera_pos
	result.offset.x += rel_pos.x
	result.offset.y += rel_pos.y
	result.offset.z += rel_pos.z

	return canonicalize(result)
}

// 重新放置low entity的chunk位置
reIndex :: proc(
	low_entity: ^LowEntity,
	low_entity_storage_index: u32,
	new_pos: WorldPosition,
	state: ^GameState,
	memory: ^Memory,
) {
	// 同一个chunk里不用变
	if (low_entity.pos.chunkXYZ == new_pos.chunkXYZ) {
		return
	}

	oldPos := low_entity.pos
	old_chunk := get_world_chunk(state, oldPos.chunkXYZ, memory)
	assert(old_chunk != nil)

	remove_entity_index_from_hash_chunk(low_entity_storage_index, old_chunk, state)

	add_entity_index_to_hash_chunk(state, memory, low_entity_storage_index, new_pos.chunkXYZ)
}

// 把计算好的high entity对应的状态（目前是未知）更新回原来的low entity
end_sim :: proc(state: ^GameState, sim_region: ^SimRegion, memory: ^Memory) {
	high_entities := sim_region.high_entities[:sim_region.high_entity_count]
	for high_entity in high_entities {
		new_pos := world_pos_add_rel(high_entity.rel_pos, state.camera_pos)
		reIndex(
			high_entity.low_entity,
			high_entity.low_entity_storage_index,
			new_pos,
			state,
			memory,
		)
		high_entity.low_entity.pos = new_pos
	}
}

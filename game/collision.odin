package game

import "core:math"
import "core:math/linalg"

Rectangle :: struct {
	min: V2,
	max: V2,
}

Box :: struct {
	min: V3,
	max: V3,
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

SIM_EPS :: math.F32_EPSILON

high_entity_rect_center :: proc(h_e: ^SimEntity) -> V2 {
	result := h_e.p
	result.y = result.y + h_e.low_entity.size.y / 2
	return V2{result.x, result.y}
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
		expanded_min       = c_a - half.xy,
		expanded_max       = c_a + half.xy,
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
	extented_A := Rectangle{pos_A - extented_A_half.xy, pos_A + extented_A_half.xy}
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
			if math.abs(ray.y) < SIM_EPS {continue} // 射线和wall都是水平线，不相交
			sweep_fraction = side.axis_pos / ray.y //投影到y轴，y=Cy时碰撞
			the_other_axis_value = ray.x * sweep_fraction // x的
		} else {
			// x = Cx 垂线 x固定，检查y
			if math.abs(ray.x) < SIM_EPS {continue} // 射线和wall都是垂线，不相交
			sweep_fraction = side.axis_pos / ray.x //投影到x轴，x=Cx时碰撞
			the_other_axis_value = ray.y * sweep_fraction
		}

		// 判断方向指向内部。不然贴边的时候，会被卡住无法离开。
		if linalg.dot(ray, side.norm_outside) < 0 &&
		   sweep_fraction >= 0 &&
		   sweep_fraction <= 1 &&
		   the_other_axis_value >= side.wall_scope.x &&
		   the_other_axis_value <= side.wall_scope.y &&
		   sweep_fraction < nearest_hit.sweep_fraction { //运动轨迹与x/y线相交叉的位置在边的范围里

			nearest_hit.hit = true
			nearest_hit.sweep_fraction = math.max(sweep_fraction - 0.001, 0)
			nearest_hit.surface = surface
		}
	}
	return nearest_hit
}

// general rule + pairwise rule
// general rules:
// pairwise-based-rules:
// 0. 默认为true
// 1. 武器和owner记录下来为false，不会碰撞（这条可以转化为owner check）
// 2. 伤害过一次就记录下来为false，下次不会重复碰撞
can_collide :: proc(ety_a: ^SimEntity, ety_b: ^SimEntity, state: ^GameState) -> bool {
	if (ety_a == ety_b) {
		return false
	}

	if !(ety_a.low_entity.collides && ety_b.low_entity.collides) {
		return false
	}

	if ety_a.low_entity.non_spatial || ety_b.low_entity.non_spatial {
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

// x=min, y=max
overlap_segment :: proc(a: V2, b: V2) -> bool {
	return !(a.x > b.y || a.y < b.x)
}

overlap_box :: proc(a: Box, b: Box) -> bool {
	return(
		overlap_segment(V2{a.min.x, a.max.x}, V2{b.min.x, b.max.x}) &&
		overlap_segment(V2{a.min.y, a.max.y}, V2{b.min.y, b.max.y}) &&
		overlap_segment(V2{a.min.z, a.max.z}, V2{b.min.z, b.max.z}) \
	)
}

entity_size_box :: proc(size: V3, pos: V3) -> Box {
	return Box {
		min = pos - V3{size.x / 2, size.y / 2, 0},
		max = pos + V3{size.x / 2, size.y / 2, size.z},
	}
}

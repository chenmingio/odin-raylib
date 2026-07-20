package game

import "core:testing"

@(test)
test_collide_minkowski_swept_aabb_hits_wall_on_right :: proc(t: ^testing.T) {
	player := LowEntity{
		type = .Player,
		size = V2{0.6, 0.7},
	}
	wall := LowEntity{
		type = .Wall,
		size = V2{0.2, 0.2},
	}

	// Player is 0.1 m from the expanded wall boundary and moves 0.2 m right.
	// The relative ray therefore reaches the wall halfway through this movement.
	a := HighEntity{low_entity = &player, rel_pos = V3{0.5, 0, 0}}
	b := HighEntity{low_entity = &wall, rel_pos = V3{1, 0, 0}}

	hit := collide_minkowski_swept_AABB(&a, &b, V2{0.2, 0})
	if !hit.hit || hit.sweep_fraction <= 0 || hit.sweep_fraction >= 1 {
		testing.fail(t)
	}
}

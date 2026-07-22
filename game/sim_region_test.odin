package game

import "core:testing"

@(test)
test_collide_minkowski_swept_aabb_hits_wall_on_right :: proc(t: ^testing.T) {
	player := LowEntity {
		type = .Player,
		size = V2{0.6, 0.7},
	}
	wall := LowEntity {
		type = .Wall,
		size = V2{0.2, 0.2},
	}

	// Player is 0.1 m from the expanded wall boundary and moves 0.2 m right.
	// The relative ray therefore reaches the wall halfway through this movement.
	a := HighEntity {
		low_entity = &player,
		rel_pos    = V3{0.5, 0, 0},
	}
	b := HighEntity {
		low_entity = &wall,
		rel_pos    = V3{1, 0, 0},
	}

	hit := collide_minkowski_swept_AABB(&a, &b, V2{0.2, 0})
	if !hit.hit || hit.sweep_fraction <= 0 || hit.sweep_fraction >= 1 {
		testing.fail(t)
	}
}

@(test)
test_simulate_stops_player_at_wall :: proc(t: ^testing.T) {
	player := LowEntity {
		type     = .Player,
		size     = V2{0.6, 0.7},
		moveable = true,
		velocity = V2{3, 0},
	}
	wall := LowEntity {
		type = .Wall,
		size = V2{0.2, 0.2},
	}

	sim_region := SimRegion{}
	sim_region.high_entities[0] = HighEntity {
		low_entity = &player,
		rel_pos    = V3{0.5, 0, 0},
	}
	sim_region.high_entities[1] = HighEntity {
		low_entity = &wall,
		rel_pos    = V3{1, 0, 0},
	}
	sim_region.high_entity_count = 2

	simulate(&sim_region, 0.1)

	// Contact occurs when the player's anchor reaches x = 0.6; without collision
	// handling, this frame would place it at x = 0.8.
	if sim_region.high_entities[0].rel_pos.x > 0.6001 {
		testing.fail(t)
	}
}

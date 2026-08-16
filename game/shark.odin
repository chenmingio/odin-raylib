package game

import "core:math"
import "core:math/linalg"

update_shark_state :: proc(
	shark: ^LowEntity,
	game_state: ^GameState,
	game_memory: ^Memory,
	dt: f32,
) {
	harpoon := get_low_entity(game_state, shark.weapon)

	player := get_low_entity(game_state, game_state.player)
	distance_to_player := relative_pos(game_state.world, player.pos, shark.pos)
	old_status := shark.status

	if shark.status == EntityStatus.Throw && shark.anim_elapsed_time > 700 {
		shark.status = EntityStatus.Idle
	}

	// 触发进入攻击状态(但是还不能扔出鱼叉)
	if shark.status == EntityStatus.Idle &&
	   harpoon.non_spatial &&
	   linalg.length(distance_to_player) < 4 {
		shark.status = EntityStatus.Throw
		shark.direction = distance_to_player.x > 0 ? Direction.Forward : Direction.Backward
	} else if shark.status == EntityStatus.Run {
		shark.ddp = -shark.dp * 5
	}

	if shark.status != old_status {
		shark.anim_frame_idx = 0
		shark.anim_elapsed_time = 0
	}

	// 到达攻击frame时，把non-spatial的武器装载状态，加入hash-chunk，设置为spatial
	if shark.status == EntityStatus.Throw &&
	   shark.anim_elapsed_time > 400 &&
	   harpoon.non_spatial == true {

		start_pos := world_pos_add(game_state.world, shark.pos, V3{0, 0.4, 0.5})
		target_pos := player.pos
		target_pos.offset.z = player.size.y / 2 //假设size.y/2不超过chunk size
		ds := relative_pos(game_state.world, target_pos, start_pos)
		t :: 0.8
		g :: V3{0, 0, -10}
		v0 := ds / t - (g * t) / 2

		harpoon.ddp = g
		harpoon.dp = v0
		harpoon.target_pos = target_pos
		harpoon.flight_time_remaining = t * 1000
		make_entity_spatial(harpoon, shark.weapon, start_pos, game_state, game_memory)

		add_collision_rule(
			game_state.shark,
			get_low_entity(game_state, game_state.shark).weapon,
			false,
			game_state,
			game_memory,
		)
	}

	// 想象frame time为1分钟，我们simulate和render是1分钟以后的世界。anim_elapsed_time应该在重置以后再加上1分钟
	shark.anim_elapsed_time += i32(dt * 1000)
	if harpoon.flight_time_remaining > 0 {
		harpoon.flight_time_remaining = math.max(0, harpoon.flight_time_remaining - i32(dt * 1000))
	}
	update_animate_frame_index(shark, game_state.harpoon_shark_animation)
}

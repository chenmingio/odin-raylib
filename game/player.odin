package game

import "core:math/linalg"

next_player_status :: proc(
	is_moving: bool,
	is_attacking_1: bool,
	is_attacking_2: bool,
	// 以后可以继续加：is_guarding, is_dead, is_hit 等
) -> EntityStatus {
	// 按优先级从高到低排：
	if is_attacking_1 {
		return .Attack_1
	}
	if is_attacking_2 {
		return .Attack_2
	}
	if is_moving {
		return .Run
	}

	return .Idle
}

update_player :: proc(state: ^GameState, input: Input, dt: f32) -> ^LowEntity {
	move := V3{0, 0, 0}
	if input.controllers[0].move_up.ended_down {
		move += V3{0, 1, 0}
	}
	if input.controllers[0].move_down.ended_down {
		move += V3{0, -1, 0}
	}
	if input.controllers[0].move_left.ended_down {
		move += V3{-1, 0, 0}
	}
	if input.controllers[0].move_right.ended_down {
		move += V3{1, 0, 0}
	}

	player := get_low_entity(state, state.player)
	player.anim_elapsed_time += i32(dt * 1000)

	player_rfd :: 10.0 //深蹲重量/体重
	is_moving := move.x != 0 || move.y != 0 || move.z != 0
	if move.x != 0 {
		player.direction = move.x > 0 ? Direction.Forward : Direction.Backward
	}

	player.ddp = linalg.normalize0(move) * player_rfd - player.dp * 5

	is_attacking_1 := input.controllers[0].action_left.ended_down
	is_attacking_2 := input.controllers[0].action_down.ended_down
	next_status := next_player_status(is_moving, is_attacking_1, is_attacking_2)
	if player.status != next_status {
		player.anim_frame_idx = 0
		player.anim_elapsed_time = 0
	}
	player.status = next_status
	update_animate_frame_index(player, state.unit_animate)

	return player
}

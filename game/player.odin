package game

import "core:math/linalg"

next_player_status :: proc(
	current_status: EntityStatus,
	animate_done: bool,
	is_moving: bool,
	try_attack_1: bool,
	try_attack_2: bool,
	try_jump: bool,
	// 以后可以继续加：is_guarding, is_dead, is_hit 等
) -> EntityStatus {
	// 跳的时候不可以攻击。
	// 按优先级从高到低排：

	// attack有cd，没有done不能修改状态
	if (current_status == .Attack_1 || current_status == .Attack_2) && !animate_done {
		return current_status
	}

	// 无cd时反应按键进入状态
	if try_attack_1 {
		return .Attack_1
	}

	if try_attack_2 {
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

	try_attack_1 := input.controllers[0].action_left.ended_down
	try_attack_2 := input.controllers[0].action_up.ended_down
	try_jump := input.controllers[0].action_down.ended_down

	animate_done := update_animate_frame_index(player, state.unit_animate)

	next_status := next_player_status(
		player.status,
		animate_done,
		is_moving,
		try_attack_1,
		try_attack_2,
		try_jump,
	)

	// status changed
	if player.status != next_status {
		player.anim_frame_idx = 0
		player.anim_elapsed_time = 0
	}
	player.status = next_status

	return player
}

package game

import "core:math/linalg"

PLAYER_JUMP_SPEED :: f32(4.5)
PLAYER_GRAVITY :: f32(9.8)

next_player_status :: proc(
	current_status: EntityStatus,
	animate_done: bool,
	is_moving: bool,
	z_supported: bool,
	try_attack_1: bool,
	try_attack_2: bool,
) -> EntityStatus {
	// 返回的status用于渲染图片，而不是用来修改状态（比如跳）

	// 跳/攻击的时候不可以修改状态
	// 跳
	if !z_supported {
		return .Jump
	}
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

update_player :: proc(state: ^GameState, input: Input) -> ^LowEntity {
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

	player_rfd :: 10.0 //深蹲重量/体重
	if move.x != 0 {
		player.direction = move.x > 0 ? Direction.Forward : Direction.Backward
	}

	// 摩擦力只作用于水平方向；重力始终施加，由顶面碰撞消除向下运动。
	player.ddp.xy = linalg.normalize0(move.xy) * player_rfd - player.dp.xy * 5

	try_jump := input.controllers[0].action_down.pressed

	// 输入使用上一帧确认的支撑状态，起跳后立即离开支撑。
	if try_jump && player.z_supported {
		player.dp.z = PLAYER_JUMP_SPEED
		player.z_supported = false
	}
	player.ddp.z = -PLAYER_GRAVITY

	return player
}

// 在模拟之后更新动画，使用本帧落地或离开平台后的支撑状态。
update_player_animation :: proc(state: ^GameState, input: Input, dt: f32) {
	player := get_low_entity(state, state.player)
	player.anim_elapsed_time += i32(dt * 1000)
	controller := input.controllers[0]
	is_moving :=
		(controller.move_left.ended_down != controller.move_right.ended_down) ||
		(controller.move_up.ended_down != controller.move_down.ended_down)
	try_attack_1 := controller.action_left.ended_down
	try_attack_2 := controller.action_up.ended_down

	animate_done := update_animate_frame_index(player, state.unit_animate)

	next_status := next_player_status(
		player.status,
		animate_done,
		is_moving,
		player.z_supported,
		try_attack_1,
		try_attack_2,
	)

	// status changed
	if player.status != next_status {
		player.anim_frame_idx = 0
		player.anim_elapsed_time = 0
	}
	player.status = next_status

}

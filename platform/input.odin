package platform

import "../game"
import rl "vendor:raylib"

update_keyboard_button :: proc(button: ^game.ButtonState, key: rl.KeyboardKey) {
	button.ended_down = rl.IsKeyDown(key)
	button.pressed = rl.IsKeyPressed(key)
}

update_keyboard_controller :: proc(controller: ^game.ControllerInput) {
	update_keyboard_button(&controller.move_up, .W)
	update_keyboard_button(&controller.move_down, .S)
	update_keyboard_button(&controller.move_left, .A)
	update_keyboard_button(&controller.move_right, .D)
	update_keyboard_button(&controller.action_left, .J) // 正攻击
	update_keyboard_button(&controller.action_up, .K) // 副攻击
	update_keyboard_button(&controller.action_down, .SPACE) // 跳
	update_keyboard_button(&controller.action_right, .RIGHT_SHIFT) // 冲刺
}

package platform

import "../game"
import rl "vendor:raylib"

update_keyboard_controller :: proc(controller: ^game.ControllerInput) {
	controller.move_up.ended_down = rl.IsKeyDown(rl.KeyboardKey.W)
	controller.move_down.ended_down = rl.IsKeyDown(rl.KeyboardKey.S)
	controller.move_left.ended_down = rl.IsKeyDown(rl.KeyboardKey.A)
	controller.move_right.ended_down = rl.IsKeyDown(rl.KeyboardKey.D)
	controller.action_left.ended_down = rl.IsKeyDown(rl.KeyboardKey.J) //正攻击
	controller.action_up.ended_down = rl.IsKeyDown(rl.KeyboardKey.K) //副攻击
	controller.action_down.ended_down = rl.IsKeyDown(rl.KeyboardKey.SPACE) //跳
	controller.action_right.ended_down = rl.IsKeyDown(rl.KeyboardKey.RIGHT_SHIFT) //冲刺
}

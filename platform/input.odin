package platform

import "../game"
import rl "vendor:raylib"

update_keyboard_controller :: proc(controller: ^game.ControllerInput) {
	controller.move_up.ended_down = rl.IsKeyDown(rl.KeyboardKey.W)
	controller.move_down.ended_down = rl.IsKeyDown(rl.KeyboardKey.S)
	controller.move_left.ended_down = rl.IsKeyDown(rl.KeyboardKey.A)
	controller.move_right.ended_down = rl.IsKeyDown(rl.KeyboardKey.D)
	controller.action_up.ended_down = rl.IsKeyDown(rl.KeyboardKey.I)
	controller.action_down.ended_down = rl.IsKeyDown(rl.KeyboardKey.K)
	controller.action_left.ended_down = rl.IsKeyDown(rl.KeyboardKey.J)
	controller.action_right.ended_down = rl.IsKeyDown(rl.KeyboardKey.L)
}

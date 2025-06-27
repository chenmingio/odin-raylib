package game
import "core:fmt"
import rl "vendor:raylib"

GameOffScreenBuffer :: struct {
	memory: rawptr,
	width:  u32,
	height: u32,
	pitch:  u32,
}

GameInput :: struct {
	controllers: [3]GameControllerInput,
}

GameButtonState :: struct {
	// half_transition_count: u32,
	ended_down: bool,
}

GameControllerInput :: struct {
	isConnected:    bool,
	isAnalog:       bool, // stick is analog, dpad is not
	stickAverageX:  f32,
	stickAverageY:  f32,
	move_up:        GameButtonState,
	move_down:      GameButtonState,
	move_left:      GameButtonState,
	move_right:     GameButtonState,
	action_up:      GameButtonState,
	action_down:    GameButtonState,
	action_left:    GameButtonState,
	action_right:   GameButtonState,
	left_shoulder:  GameButtonState,
	right_shoulder: GameButtonState,
	start:          GameButtonState,
	back:           GameButtonState,
}

game_update_and_render :: proc(input: GameInput) {

	gameMap := [5]i32{1, 0, 1, 0, 1}

	offset := i32(0)
	if input.controllers[0].move_up.ended_down {
		offset += 1
	}
	if input.controllers[0].move_down.ended_down {
		offset -= 1
	}

	for i in gameMap {
		rl.DrawRectangle(i * 100 + offset * 10, 100, 100, 100, rl.BLUE)
	}

}

package game

Input :: struct {
	controllers: [3]ControllerInput,
}

ButtonState :: struct {
	// half_transition_count: u32,
	ended_down: bool,
}

ControllerInput :: struct {
	isConnected:    bool,
	isAnalog:       bool, // stick is analog, dpad is not
	stickAverageX:  f32,
	stickAverageY:  f32,
	move_up:        ButtonState,
	move_down:      ButtonState,
	move_left:      ButtonState,
	move_right:     ButtonState,
	action_up:      ButtonState,
	action_down:    ButtonState,
	action_left:    ButtonState,
	action_right:   ButtonState,
	left_shoulder:  ButtonState,
	right_shoulder: ButtonState,
	start:          ButtonState,
	back:           ButtonState,
}

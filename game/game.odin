package game
import "base:intrinsics"
import "core:fmt"
import "core:slice"
import rl "vendor:raylib"

// RGBA
RED := intrinsics.byte_swap(u32(0xFF0000FF))
GREEN := intrinsics.byte_swap(u32(0x00FF00FF))
BLUE := intrinsics.byte_swap(u32(0x0000FFFF))

SoundOutputBuffer :: struct {
	samples:            [^]i16,
	samples_per_second: u32,
	sample_count:       u32,
}

Memory :: struct {
	permanent_storage:      [^]u8,
	permanent_storage_size: u64,
	transient_storage:      [^]u8,
	transient_storage_size: u64,
}

OffScreenBuffer :: struct {
	data:   []u32,
	width:  u32,
	height: u32,
	pitch:  u32,
}

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


UpdateAndRenderProc :: #type proc(
	game_memory: ^Memory,
	input: Input,
	image_buffer: OffScreenBuffer,
	time_span: f32,
)

GetSoundSamplesProc :: #type proc(game_memory: ^Memory, sound_buffer: ^SoundOutputBuffer)

@(export)
update_and_render: UpdateAndRenderProc : proc(
	game_memory: ^Memory,
	input: Input,
	image_buffer: OffScreenBuffer,
	time_span: f32,
) {

	gameMap :: [5]i32{1, 0, 1, 0, 1}

	offset := i32(0)

	color := BLUE

	if input.controllers[0].move_up.ended_down {
		offset += 100
		color = RED
	}
	if input.controllers[0].move_down.ended_down {
		offset -= 100
		color = GREEN
	}

	slice.fill(image_buffer.data[0:70000], color)

}

@(export)
get_sound_samples: GetSoundSamplesProc : proc(
	game_memory: ^Memory,
	sound_buffer: ^SoundOutputBuffer,
) {
}

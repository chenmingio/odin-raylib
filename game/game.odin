package game
import "core:fmt"
import rl "vendor:raylib"

// 游戏声音输出缓冲区
SoundOutputBuffer :: struct {
	samples:            [^]i16,
	samples_per_second: u32,
	sample_count:       u32,
}

// 游戏内存结构
Memory :: struct {
	permanent_storage:      [^]u8,
	permanent_storage_size: u64,
	transient_storage:      [^]u8,
	transient_storage_size: u64,

	// 内部调试功能
	// 如果需要添加调试函数指针，可以在这里添加
}

OffScreenBuffer :: struct {
	memory: rawptr,
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
	input: ^Input,
	image_buffer: ^OffScreenBuffer,
	time_span: f32,
)

GetSoundSamplesProc :: #type proc(game_memory: ^Memory, sound_buffer: ^SoundOutputBuffer)

@(export)
update_and_render: UpdateAndRenderProc : proc(
	game_memory: ^Memory,
	input: ^Input,
	image_buffer: ^OffScreenBuffer,
	time_span: f32,
) {

	gameMap := [5]i32{1, 0, 1, 0, 1}

	offset := i32(0)
	if input.controllers[0].move_up.ended_down {
		offset += 100
	}
	if input.controllers[0].move_down.ended_down {
		offset -= 100
	}

	// for i in gameMap {
	// 	rl.DrawRectangle(i * 100 + offset * 10, 100, 100, 100, rl.BLUE)
	// }

}

@(export)
get_sound_samples: GetSoundSamplesProc : proc(
	game_memory: ^Memory,
	sound_buffer: ^SoundOutputBuffer,
) {
}

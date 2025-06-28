package game
import "core:fmt"
import "core:math/linalg"
import "core:mem"
import rl "vendor:raylib"


V2 :: linalg.Vector2f32

GameState :: struct {}

// TODO restruct with chunks and relPos
WorldPos :: linalg.Vector2f32

ScreenPos :: linalg.Vector2f32

Rectangle :: struct {
	min: V2,
	max: V2,
}

Memory :: struct {
	arena:          mem.Arena,
	is_initialized: bool,
}

UpdateAndRenderProc :: #type proc(
	memory: ^Memory,
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

	game_state: ^GameState
	if !game_memory.is_initialized {
		game_state = new(GameState) // already set arena as default allocator
		game_memory.is_initialized = true
	} else {
		game_state = cast(^GameState)&game_memory.arena.data[0]
	}

	game_map :: [5]i32{1, 0, 1, 0, 1}

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

	draw_rectangle(0, 0, 100, 100, RED, image_buffer)
	draw_rectangle(750, 0, 100, 100, GREEN, image_buffer)
	draw_rectangle(750, 550, 100, 100, BLUE, image_buffer)

	draw_entity_rectangle(ScreenPos{0, 0}, 100, 100, color, image_buffer)
}

@(export)
get_sound_samples: GetSoundSamplesProc : proc(
	game_memory: ^Memory,
	sound_buffer: ^SoundOutputBuffer,
) {
}

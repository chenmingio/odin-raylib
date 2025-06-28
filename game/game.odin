package game
import "base:intrinsics"
import "core:fmt"
import "core:math/linalg"
import "core:slice"
import rl "vendor:raylib"

// RGBA
RED := intrinsics.byte_swap(u32(0xFF0000FF))
GREEN := intrinsics.byte_swap(u32(0x00FF00FF))
BLUE := intrinsics.byte_swap(u32(0x0000FFFF))
BLACK := intrinsics.byte_swap(u32(0x000000FF))

V2 :: linalg.Vector2f32

WorldPos :: linalg.Vector2f32

CameraPos :: linalg.Vector2f32

Rectangle :: struct {
	min: V2,
	max: V2,
}

// pos is at the gravity center of entity
draw_entity_rectangle :: proc(
	pos: CameraPos,
	width: u32,
	height: u32,
	color: u32,
	buffer: OffScreenBuffer,
) {
	center_x := i32(buffer.width) / 2 + i32(pos.x)
	center_y := i32(buffer.height) / 2 - i32(pos.y)

	draw_rectangle(center_x - i32(width) / 2, center_y - i32(height), width, height, color, buffer)
}

// for screen space, 00 is top left, 11 is bottom right
// x, y are top left
draw_rectangle :: proc(
	x: i32,
	y: i32,
	width: u32,
	height: u32,
	color: u32,
	buffer: OffScreenBuffer,
) {
	x := u32(max(0, x))
	y := u32(max(0, y))

	minX := min(x, buffer.width)
	maxX := min(x + width, buffer.width)
	minY := min(y, buffer.height)
	maxY := min(y + height, buffer.height)
	for row in minY ..< maxY {
		rowOffset := row * buffer.width
		pixels := buffer.data[rowOffset + minX:rowOffset + maxX]
		slice.fill(pixels, color)
	}
}

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

	draw_rectangle(0, 0, 100, 100, RED, image_buffer)
	draw_rectangle(750, 0, 100, 100, GREEN, image_buffer)
	draw_rectangle(750, 550, 100, 100, BLUE, image_buffer)

	draw_entity_rectangle(CameraPos{0, 0}, 100, 100, color, image_buffer)
}

@(export)
get_sound_samples: GetSoundSamplesProc : proc(
	game_memory: ^Memory,
	sound_buffer: ^SoundOutputBuffer,
) {
}

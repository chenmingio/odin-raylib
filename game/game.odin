package game
import "core:fmt"
import "core:math/linalg"
import "core:mem"
import "core:relative"
import rl "vendor:raylib"


V2 :: linalg.Vector2f32
V2i :: [2]i32

chunkSize :: u32(128)

WorldPos :: struct {
	chunkXY: V2i,
	relXY:   V2,
}

relative_pos :: proc(x, y: WorldPos) -> V2 {
	return x.relXY - y.relXY + linalg.to_f32((x.chunkXY - y.chunkXY) * i32(chunkSize))
}


GameState :: struct {
	camera_pos: WorldPos,
	player:     Entity,
}


ScreenPos :: V2

Rectangle :: struct {
	min: V2,
	max: V2,
}

Memory :: struct {
	is_initialized:    bool,
	permanent_storage: rawptr,
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
		// already set arena as default allocator
		game_state = new(GameState)
		game_memory.permanent_storage = game_state
		game_state^.camera_pos = WorldPos{V2i{0, 0}, V2{0, 0}}
		game_state^.player = Entity {
			WorldPos{V2i{0, 0}, V2{0.5, 0.5}},
			EntityType.Player,
			V2{0.8, 1.8},
		}

		game_memory.is_initialized = true
	} else {
		game_state = cast(^GameState)game_memory.permanent_storage
	}

	game_map :: [5]i32{1, 0, 1, 0, 1}
	draw_rectangle(0, 0, 800, 600, WHITE, image_buffer)

	move: V2
	if input.controllers[0].move_up.ended_down {
		move = V2{0, 10}
	}
	if input.controllers[0].move_down.ended_down {
		move = V2{0, -10}
	}
	if input.controllers[0].move_left.ended_down {
		move = V2{-10, 0}
	}
	if input.controllers[0].move_right.ended_down {
		move = V2{10, 0}
	}

	game_state^.player.pos.relXY += move

	// draw_rectangle(0, 0, 100, 100, RED, image_buffer)
	// draw_rectangle(750, 0, 100, 100, GREEN, image_buffer)
	// draw_rectangle(750, 550, 100, 100, BLUE, image_buffer)

	player := game_state^.player
	draw_entity_rectangle(
		relative_pos(player.pos, game_state^.camera_pos),
		u32(player.size.x * 100),
		u32(player.size.y * 100),
		BLUE,
		image_buffer,
	)
}

@(export)
get_sound_samples: GetSoundSamplesProc : proc(
	game_memory: ^Memory,
	sound_buffer: ^SoundOutputBuffer,
) {
}

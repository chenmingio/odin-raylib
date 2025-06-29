package game
import "core:fmt"
import "core:math/linalg"
import "core:mem"
import "core:relative"
import rl "vendor:raylib"


V2 :: linalg.Vector2f32
V2i :: [2]i32

chunkSize :: u32(16)

WorldPos :: struct {
	chunkXY: V2i,
	relXY:   V2,
}

relative_pos :: proc(x, y: WorldPos) -> V2 {
	return x.relXY - y.relXY + linalg.to_f32((x.chunkXY - y.chunkXY) * i32(chunkSize))
}


GameState :: struct {
	camera_pos:   WorldPos,
	player:       ^Entity,
	entities:     [1000]Entity,
	entity_count: u32,
}

meter_to_pixel :: f32(20.0)
wall_size :: f32(2.0)

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

		game_state^.entities[game_state^.entity_count] = Entity {
			WorldPos{V2i{0, 1}, V2{0.5, 0.5}},
			EntityType.Player,
			V2{2.8, 3.8},
		}
		game_state^.player = &game_state^.entities[game_state^.entity_count]
		game_state^.entity_count += 1

		for i in 0 ..< 10 {
			entity := Entity {
				WorldPos{V2i{i32(i), 0}, V2{0.5, 0.5}},
				EntityType.Wall,
				V2{wall_size, wall_size},
			}
			game_state^.entities[game_state^.entity_count] = entity
			game_state^.entity_count += 1
		}

		game_memory.is_initialized = true
	} else {
		game_state = cast(^GameState)game_memory.permanent_storage
	}

	game_map :: [5]i32{1, 0, 1, 0, 1}
	draw_rectangle(0, 0, 800, 600, WHITE, image_buffer)

	move: V2
	if input.controllers[0].move_up.ended_down {
		move = V2{0, 0.1}
	}
	if input.controllers[0].move_down.ended_down {
		move = V2{0, -0.1}
	}
	if input.controllers[0].move_left.ended_down {
		move = V2{-0.1, 0}
	}
	if input.controllers[0].move_right.ended_down {
		move = V2{0.1, 0}
	}
	game_state^.player^.pos.relXY += move

	for entity_idx in 0 ..< game_state^.entity_count {
		entity := game_state^.entities[entity_idx]
		relative_pos := relative_pos(entity.pos, game_state^.camera_pos) * meter_to_pixel
		width := i32(entity.size.x * meter_to_pixel)
		height := i32(entity.size.y * meter_to_pixel)
		switch entity.type {
		case EntityType.Player:
			draw_entity_rectangle(relative_pos, width, height, BLUE, image_buffer)
			break
		case EntityType.Wall:
			draw_entity_rectangle(relative_pos, width, height, GREEN, image_buffer)
			break
		case EntityType.Tree:
			break
		case EntityType.Enemy:
			break
		case EntityType.Null:
			fmt.eprint(">>> Null entity should not be rendered")
			break
		}
	}
}

@(export)
get_sound_samples: GetSoundSamplesProc : proc(
	game_memory: ^Memory,
	sound_buffer: ^SoundOutputBuffer,
) {
}

package game
import "core:fmt"
import "core:image"
import "core:image/png"
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
	background:   ^image.Image,
	img_hero:     [4]^image.Image,
}

World :: struct {
	tileSideInMeters:  f32,
	chunkSideInMeters: f32,
}

wall_size :: f32(2.0)

ScreenPos :: V2

Rectangle :: struct {
	min: V2i,
	max: V2i,
}

// permanent_storage doesn't equal to data ptr of arena (becuase there is metadata at the beginning of arena),
// it's assigned when you first allocate something
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

	// in c version, game_state *GameState = (game_state *)Memory->PermanentStorage;
	// in odin version, I need to call new to allocate memory for game_state
	using game_state: ^GameState
	if !game_memory.is_initialized {
		// already set arena as default allocator
		game_state = new(GameState)
		// storage starts from the first byte of allocated memory, not arena's data ptr
		// TODO consider use odin arena directly and remove memory struct, if odin's arena can handle recording/export well
		game_memory.permanent_storage = game_state
		camera_pos = WorldPos{V2i{0, 0}, V2{0, 0}}

		entities[entity_count] = Entity {
			WorldPos{V2i{0, 1}, V2{0.5, 0.5}},
			EntityType.Player,
			V2{2.8, 3.8},
		}
		player = &entities[entity_count]
		entity_count += 1

		for i in 0 ..< 10 {
			entity := Entity {
				WorldPos{V2i{i32(i), 0}, V2{0.5, 0.5}},
				EntityType.Wall,
				V2{wall_size, wall_size},
			}
			entities[entity_count] = entity
			entity_count += 1
		}

		background_img, err := image.load_from_file(
			"resources/background_pink_sky.png",
			{},
			context.temp_allocator, // temporary allocator which will be freed as whole
		)
		assert(err == nil)
		game_state^.background = background_img

		hero_img, load_err := image.load_from_file(
			"resources/warrior_blue_run.png",
			{},
			context.temp_allocator,
		)
		assert(load_err == nil)
		game_state^.img_hero[0] = hero_img


		game_memory.is_initialized = true
	} else {
		game_state = cast(^GameState)game_memory.permanent_storage
	}

	game_map :: [5]i32{1, 0, 1, 0, 1}
	meter_to_pixel :: f32(20.0)
	draw_rectangle(0, 0, 800, 600, WHITE, image_buffer)

	draw_image(0, 0, game_state^.background, image_buffer)

	move := V2{0, 0}
	if input.controllers[0].move_up.ended_down {
		move += V2{0, 0.1}
	}
	if input.controllers[0].move_down.ended_down {
		move += V2{0, -0.1}
	}
	if input.controllers[0].move_left.ended_down {
		move += V2{-0.1, 0}
	}
	if input.controllers[0].move_right.ended_down {
		move += V2{0.1, 0}
	}
	player^.pos.relXY += move

	for entity_idx in 0 ..< entity_count {
		using entity := entities[entity_idx]
		rel_pos := relative_pos(pos, camera_pos) * meter_to_pixel
		width := i32(size.x * meter_to_pixel)
		height := i32(size.y * meter_to_pixel)

		assert(type != .Null)

		#partial switch type {
		case .Player:
			draw_entity_rectangle(rel_pos, width, height, BLUE, image_buffer)
		// draw_animation(
		// 	i32(rel_pos.x),
		// 	i32(rel_pos.y),
		// 	game_state^.img_hero[entity_idx],
		// 	image_buffer,
		// 	4,
		// 	i32(entity_idx),
		// )
		case .Wall:
			draw_entity_rectangle(rel_pos, width, height, GREEN, image_buffer)
		case .Tree:
		case .Enemy:
		}
	}
}

@(export)
get_sound_samples: GetSoundSamplesProc : proc(
	game_memory: ^Memory,
	sound_buffer: ^SoundOutputBuffer,
) {
}

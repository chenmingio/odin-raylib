package game
import "core:image"
import "core:image/png" // 必须保留！用于注册 PNG 加载器
import "core:math/linalg"
import "core:mem"


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

Memory :: struct {
	is_initialized:    bool,
	permanent_storage: []byte,
	perm_alloc:        mem.Allocator,
	temp_alloc:        mem.Allocator,
}

// 动态函数类型
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

	// 之前以为不能premanent_storage直接拿来用，其实是可以的。
	// 只不过他是个slice，有元数据，要用raw_data来指向slice的data区域
	game_state := cast(^GameState)raw_data(game_memory.permanent_storage)
	if !game_memory.is_initialized {
		// 初始化工作
		// 设置初始相机位置
		game_state^.camera_pos = WorldPos{V2i{0, 0}, V2{0, 0}}

		// 加载entities
		player := Entity{WorldPos{V2i{0, 1}, V2{0.5, 0.5}}, EntityType.Player, V2{2.8, 3.8}}
		add_entity(game_state, player)
		game_state^.player = &game_state^.entities[0]

		for i in 0 ..< 10 {
			entity := Entity {
				WorldPos{V2i{i32(i), 0}, V2{0.5, 0.5}},
				EntityType.Wall,
				V2{wall_size, wall_size},
			}
			add_entity(game_state, entity)
		}

		        // 加载图片
        background_img, err := image.load_from_file(
            "resources/background_pink_sky.png",
            {},
            game_memory.temp_alloc, // 使用主程序传入的临时分配器
        )
        assert(err == nil)
        game_state^.background = background_img

        hero_img, load_err := image.load_from_file(
            "resources/warrior_blue_run.png",
            {},
            game_memory.temp_alloc,
        )
        assert(load_err == nil)
        game_state^.img_hero[0] = hero_img

		// 完成
		game_memory.is_initialized = true
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
	game_state^.player^.pos.relXY += move


	// render
	for entity in active_entities(game_state) {
		using entity
		rel_pos := relative_pos(pos, game_state^.camera_pos) * meter_to_pixel
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

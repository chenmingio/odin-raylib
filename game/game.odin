package game
import "core:image"
import "core:image/png" // 必须保留！用于注册 PNG 加载器
import "core:math/linalg"


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

// 辅助函数：获取活跃实体的 slice
active_entities :: proc(state: ^GameState) -> []Entity {
	return state.entities[:state.entity_count]
}

// 辅助函数：添加实体
add_entity :: proc(state: ^GameState, entity: Entity) -> bool {
	if state.entity_count < len(state.entities) {
		state.entities[state.entity_count] = entity
		state.entity_count += 1
		return true
	}
	return false // 数组满了
}

// 辅助函数：删除实体（交换到末尾然后删除）
remove_entity :: proc(state: ^GameState, index: u32) {
	if index < state.entity_count {
		// 把最后一个实体移到被删除的位置
		state.entities[index] = state.entities[state.entity_count - 1]
		state.entity_count -= 1
	}
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
	permanent_storage: []byte,
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

	for entity_idx in 0 ..< game_state^.entity_count {
		using entity := game_state^.entities[entity_idx]
		rel_pos := relative_pos(entity.pos, game_state^.camera_pos) * meter_to_pixel
		width := i32(entity.size.x * meter_to_pixel)
		height := i32(entity.size.y * meter_to_pixel)

		assert(entity.type != .Null)

		#partial switch entity.type {
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

package game
import "core:image"
import "core:image/png" // 必须保留！用于注册 PNG 加载器
import "core:math/linalg"
import "core:mem"


V2 :: linalg.Vector2f32
V3 :: linalg.Vector3f32
V2i :: [2]i32
V3i :: [3]i32

chunkSize :: u32(16)

// in meter
WorldPos :: struct {
	xyz: V3i,
	rel: V3,
}

ChunkPos :: V3i

canonicalize :: proc(p: WorldPos) -> WorldPos {
	pos := p

	// 1) 取相对位移的整数部分（向零截断）
	d := V3i{i32(pos.rel.x), i32(pos.rel.y), i32(pos.rel.z)}

	// 2) 整数部分进位到块坐标
	pos.xyz += d

	// 3) 从相对位移里扣掉整数部分
	pos.rel.x -= f32(d[0])
	pos.rel.y -= f32(d[1])
	pos.rel.z -= f32(d[2])

	return pos
}

relative_pos :: proc(p1, p2: WorldPos) -> V3 {
	di := p1.xyz - p2.xyz // [3]i32
	df := V3{f32(di.x), f32(di.y), f32(di.z)} // Vector3f32
	return df + p1.rel - p2.rel
}

world_pos_add :: proc(p: WorldPos, d: V3) -> WorldPos {
	p := p
	p.rel += d
	return canonicalize(p)
}

AnimateImage :: struct {
	image:             ^image.Image,
	frame_count:       i32, // 横向分割画幅
	frame_index:       i32, // 当前画幅
	updates_per_frame: i32, // 每多少帧移动到下一个frame
	update_counter:    i32, // 累计了多少帧
}

HeroImgs :: struct {
	attack1, attack2, guard, idle, run: AnimateImage,
}

GameState :: struct {
	camera_pos:   WorldPos,
	player:       ^Entity,
	entities:     [1000]Entity,
	entity_count: u32,
	background:   ^image.Image,
	img_hero:     HeroImgs,
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
		game_state^.camera_pos = WorldPos{V3i{}, V3{}}

		// 加载entities
		player := Entity{WorldPos{V3i{0, 1, 0}, V3{0.5, 0.5, 0}}, EntityType.Player, V2{2.8, 3.8}}
		add_entity(game_state, player)
		game_state^.player = &game_state^.entities[0]

		for i in 0 ..< 10 {
			entity := Entity {
				WorldPos{V3i{i32(i), 0, 0}, V3{0.5, 0.5, 0}},
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
			"resources/Units/Black Units/Warrior/Warrior_Run.png",
			{},
			game_memory.temp_alloc,
		)

		assert(load_err == nil)
		game_state^.img_hero.run = AnimateImage{hero_img, 6, 0, 6, 0}

		// 完成
		game_memory.is_initialized = true
	}

	game_map :: [5]i32{1, 0, 1, 0, 1}
	meter_to_pixel :: f32(20.0)
	draw_rectangle(0, 0, 800, 600, WHITE, image_buffer)

	draw_image(0, 0, game_state^.background, image_buffer)

	move := V3{0, 0, 0}
	if input.controllers[0].move_up.ended_down {
		move += V3{0, 1, 0}
	}
	if input.controllers[0].move_down.ended_down {
		move += V3{0, -1, 0}
	}
	if input.controllers[0].move_left.ended_down {
		move += V3{-1, 0, 0}
	}
	if input.controllers[0].move_right.ended_down {
		move += V3{1, 0, 0}
	}
	game_state^.player^.pos = world_pos_add(game_state^.player^.pos, move)


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
			draw_animation(rel_pos, &game_state^.img_hero.run, image_buffer)
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

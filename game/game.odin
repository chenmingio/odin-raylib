package game

import "core:encoding/json" // 必须保留！用于注册 PNG 加载器
import "core:image"
import "core:image/png"
import "core:math/linalg"
import "core:mem"
import "core:os"


V2 :: linalg.Vector2f32
V3 :: linalg.Vector3f32
V2i :: [2]i32
V3i :: [3]i32

chunkSize :: u32(16)

SCALE :: f32(100.0)

meter_to_pixel_f32 :: proc(x: f32) -> f32 {
	return x * SCALE
}

meter_to_pixel_v2 :: proc(v: V2) -> V2 {
	return V2{v.x * SCALE, v.y * SCALE}
}

meter_to_pixel_v3 :: proc(v: V3) -> V3 {
	return V3{v.x * SCALE, v.y * SCALE, v.z * SCALE}
}

meter_to_pixel :: proc {
	meter_to_pixel_f32,
	meter_to_pixel_v2,
	meter_to_pixel_v3,
}


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

choose_status :: proc(
	is_moving: bool,
	is_attacking_1: bool,
	is_attacking_2: bool,
	// 以后可以继续加：is_guarding, is_dead, is_hit 等
) -> EntityStatus {
	// 按优先级从高到低排：
	if is_attacking_1 {
		return .Attack_1
	}
	if is_attacking_2 {
		return .Attack_2
	}
	if is_moving {
		return .Run
	}

	return .Idle
}


GameState :: struct {
	camera_pos:   WorldPos,
	player:       ^Entity,
	entities:     [1000]Entity,
	entity_count: u32,
	background:   ^image.Image,
	unit_animate: Animation,
	tilemap1:     ^image.Image,
}

CorppedImage :: struct {
	image:  ^image.Image,
	size:   V2i,
	offset: V2i,
}


World :: struct {
	tileSideInMeters:  f32,
	chunkSideInMeters: f32,
}

wall_size :: f32(3.0)

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
		// 以米为单位
		player := Entity {
			WorldPos{V3i{0, 0, 0}, V3{0, 0, 0}},
			EntityType.Player,
			V2{1.0, 1.2},
			EntityStatus.Idle,
			0,
			0,
		}
		add_entity(game_state, player)
		game_state^.player = &game_state^.entities[0]

		for i in 0 ..< 10 {
			entity := Entity {
				WorldPos{V3i{i32(i), 0, 0}, V3{5, 5, 0}},
				EntityType.Wall,
				V2{wall_size, wall_size},
				EntityStatus.Null,
				0,
				0,
			}
			add_entity(game_state, entity)
		}

		// 背景图片（目前加载后太卡了，先注释掉）
		// background_img, err := image.load_from_file(
		// 	"resources/background_pink_sky.png",
		// 	{},
		// 	game_memory.temp_alloc, // 使用主程序传入的临时分配器
		// )
		// assert(err == nil)
		// game_state^.background = background_img

		unit_img, load_err := image.load_from_file(
			"resources/Units/Warrior.png",
			{},
			game_memory.temp_alloc,
		)
		assert(load_err == nil)
		unit_json, ok := os.read_entire_file(
			"resources/Units/Warrior.json",
			game_memory.temp_alloc,
		)
		assert(ok)
		unit_animate := AseSpriteSheet{}
		parse_err := json.unmarshal(unit_json, &unit_animate)
		assert(parse_err == nil)
		game_state^.unit_animate = animation_from_ase_sprite_sheet(
			unit_animate,
			unit_img,
			V2i{80, 120},
		)

		// 完成
		game_memory.is_initialized = true
	}

	game_map :: [5]i32{1, 0, 1, 0, 1}
	draw_rectangle(0, 0, image_buffer.width, image_buffer.height, GREEN, image_buffer)

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

	player_speed :: 3.0

	is_moving := move.x != 0 || move.y != 0 || move.z != 0
	is_attacking_1 := input.controllers[0].action_left.ended_down
	is_attacking_2 := input.controllers[0].action_down.ended_down
	new_status := choose_status(is_moving, is_attacking_1, is_attacking_2)
	if (game_state^.player^.status != EntityStatus.Null &&
		   game_state^.player^.status != new_status) {
		game_state^.player^.anim_frame_idx = 0
		game_state^.player^.anim_time = 0
	}
	game_state^.player^.status = new_status

	game_state^.player^.pos = world_pos_add(
		game_state^.player^.pos,
		move * player_speed * time_span,
	)

	// render

	draw_line_x(image_buffer.height / 2, image_buffer)
	draw_line_y(image_buffer.width / 2, image_buffer)

	entities := active_entities(game_state)
	for i in 0 ..< len(entities) {
		entity := &entities[i]

		// 屏幕中心与相对像素偏移
		screen_center := V2i{image_buffer.width / 2, image_buffer.height / 2}
		rel_pos_px := meter_to_pixel(relative_pos(entity.pos, game_state^.camera_pos)) // V3
		rel_px := V2i{i32(rel_pos_px.x), -i32(rel_pos_px.y)} // 上为负

		// 是否玩家
		is_player := entity.type == EntityType.Player

		// 玩家帧尺寸 or 一般实体尺寸（米→像素）
		size_px := V2i{i32(meter_to_pixel(entity.size.x)), i32(meter_to_pixel(entity.size.y))}

		// 左上角 = 屏幕中心 + 相对偏移 - 重心到左上角调整(半宽, 全高)
		top_left := screen_center + rel_px - V2i{size_px.x / 2, size_px.y}

		#partial switch entity.type {
		case .Player:
			draw_animation(top_left, game_state.unit_animate, entity, image_buffer, time_span)
			draw_rectangle(top_left.x, top_left.y, size_px.x, size_px.y, RED, image_buffer, true)
		case .Wall:
			draw_rectangle(top_left.x, top_left.y, size_px.x, size_px.y, GREEN, image_buffer)
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

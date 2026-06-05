package game

import "core:encoding/json" // 必须保留！用于注册 PNG 加载器
import "core:fmt"
import "core:image"
import "core:image/png"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:os"


V2 :: linalg.Vector2f32
V3 :: linalg.Vector3f32
V2i :: [2]i32
V3i :: [3]i32

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

next_status :: proc(
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
	camera_pos:   WorldPosition,
	player:       ^LowEntity,
	entities:     [10000]LowEntity,
	entity_count: u32,
	background:   ^image.Image,
	unit_animate: Animation,
	tilemap1:     ^image.Image,
	game_map:     [tileMapY][tileMapX]V2i,
	rock_images:  [4]^image.Image,
	world:        World,
}

CorppedImage :: struct {
	image:  ^image.Image,
	size:   V2i,
	offset: V2i,
}


wall_size :: f32(0.2)

ScreenPos :: V2

tileMapX :: 16
tileMapY :: 10

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
	rand.reset(12345)
	// 之前以为不能premanent_storage直接拿来用，其实是可以的。
	// 只不过他是个slice，有元数据，要用raw_data来指向slice的data区域
	game_state := cast(^GameState)raw_data(game_memory.permanent_storage)
	if !game_memory.is_initialized {
		// 初始化工作
		// 设置初始相机位置
		game_state^.camera_pos = WorldPosition{V3i{}, V3{}}
		// 地图
		for y in 0 ..< tileMapY {
			for x in 0 ..< tileMapX {
				if (x == 0 && y == 0) {
					game_state^.game_map[y][x] = V2i{0, 0}
				} else if (x == tileMapX - 1 && y == 0) {
					game_state^.game_map[y][x] = V2i{2, 0}
				} else if (x == 0 && y == tileMapY - 1) {
					game_state^.game_map[y][x] = V2i{0, 2}
				} else if (x == tileMapX - 1 && y == tileMapY - 1) {
					game_state^.game_map[y][x] = V2i{2, 2}
				} else if (x == 0) {
					game_state^.game_map[y][x] = V2i{0, 1}
				} else if (x == tileMapX - 1) {
					game_state^.game_map[y][x] = V2i{2, 1}
				} else if (y == 0) {
					game_state^.game_map[y][x] = V2i{1, 0}
				} else if (y == tileMapY - 1) {
					game_state^.game_map[y][x] = V2i{1, 2}
				} else {
					game_state^.game_map[y][x] = V2i{1, 1}
				}
			}
		}
		// chunk
		game_state^.chunks = make(map[WorldPosition]WorldChunk, game_memory.perm_alloc)

		// 加载entities
		// 以米为单位
		player := LowEntity {
			WorldPosition{V3i{0, 0, 0}, V3{0, 0, 0}},
			EntityType.Player,
			V2{0.8, 0.8},
			EntityStatus.Idle,
			0,
			0,
			Direction.Forward,
		}
		add_entity(game_state, player, game_memory)
		game_state^.player = &game_state^.entities[0]

		for i in 0 ..< 10 {
			entity := LowEntity {
				WorldPosition{V3i{i32(i), 0, 0}, V3{5, 5, 0}},
				EntityType.Wall,
				V2{wall_size, wall_size},
				EntityStatus.Null,
				0,
				0,
				Direction.Forward,
			}
			add_entity(game_state, entity, game_memory)
		}
		// 石头
		for i in 0 ..< 4 {
			rock, err_load_rock := image.load_from_file(
				fmt.tprintf("resources/Decorations/Rocks/Rock%d.png", i + 1),
				{},
				game_memory.temp_alloc,
			)
			assert(err_load_rock == nil)
			game_state^.rock_images[i] = rock
		}


		// 载入地面
		tilemap1, err_load_tilemap1 := image.load_from_file(
			"resources/Terrain/Tilemap_color1.png",
			{},
			game_memory.temp_alloc, // 使用主程序传入的临时分配器
		)
		assert(err_load_tilemap1 == nil)
		game_state^.tilemap1 = tilemap1

		// 载入单位动画
		unit_img, err_load_unit_img := image.load_from_file(
			"resources/Units/Warrior.png",
			{},
			game_memory.temp_alloc,
		)
		assert(err_load_unit_img == nil)
		unit_json, json_err := os.read_entire_file(
			"resources/Units/Warrior.json",
			game_memory.temp_alloc,
		)
		assert(json_err == nil)
		unit_animate := AseSpriteSheet{}
		parse_err := json.unmarshal(unit_json, &unit_animate)
		assert(parse_err == nil)
		game_state^.unit_animate = animation_from_ase_sprite_sheet(
			unit_animate,
			unit_img,
			V2i{0, 0},
			"Warrior",
		)


		// 完成
		game_memory.is_initialized = true
	}

	// 绿布
	draw_rectangle(0, 0, image_buffer.width, image_buffer.height, GREEN, image_buffer)

	// 控制输入
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

	// 运动模拟
	player_speed :: 3.0

	is_moving := move.x != 0 || move.y != 0 || move.z != 0
	if (move.x != 0) {
		game_state^.player^.direction = (move.x > 0 ? Direction.Forward : Direction.Backward)
	}

	is_attacking_1 := input.controllers[0].action_left.ended_down
	is_attacking_2 := input.controllers[0].action_down.ended_down
	next_status := next_status(is_moving, is_attacking_1, is_attacking_2)
	if (game_state^.player^.status != EntityStatus.Null &&
		   game_state^.player^.status != next_status) {
		game_state^.player^.anim_frame_idx = 0
		game_state^.player^.anim_time = 0
	}
	game_state^.player^.status = next_status

	game_state^.player^.pos = world_pos_add(
		game_state^.player^.pos,
		move * player_speed * time_span,
	)

	// game_state^.camera_pos = game_state^.player^.pos

	// 绘制
	sim_region := begin_sim(game_state, game_memory)

	// 简单绘制tilemap
	// draw map
	for y in 0 ..< tileMapY {
		for x in 0 ..< tileMapX {
			tile := game_state^.game_map[y][x]
			draw_tile_map(V2i{i32(x), i32(y)}, tile, game_state^.tilemap1, image_buffer)
		}
	}

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

		// 对象左上角 = 屏幕中心 + 相对偏移 - 重心到左上角调整(半宽, 全高)
		top_left := screen_center + rel_px - V2i{size_px.x / 2, size_px.y}

		switch entity.type {
		case .Player:
			draw_entity_animation(
				top_left,
				game_state.unit_animate,
				entity,
				image_buffer,
				time_span,
			)
		case .Wall:
			draw_entity_image(top_left, game_state^.rock_images[0], entity, image_buffer)
		case .Tree:
		case .Enemy:
		case .Null:
			break
		}
	}

	// render
	draw_line_x(image_buffer.height / 2, image_buffer)
	draw_line_y(image_buffer.width / 2, image_buffer)


}

@(export)
get_sound_samples: GetSoundSamplesProc : proc(
	game_memory: ^Memory,
	sound_buffer: ^SoundOutputBuffer,
) {
}

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
		// 初始化玩家
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

		// 初始化地图
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

		// 加载asset
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
			V2i{95, 130},
			"Warrior",
		)


		// 完成初始化
		game_memory.is_initialized = true
	}

	// 画一个绿布
	draw_rectangle(V2i{0, 0}, V2i{image_buffer.width, image_buffer.height}, GREEN, image_buffer)

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

	game_state^.camera_pos = game_state^.player^.pos

	// 准备好初始条件（物体，初始速度）以后，开始区域计算模拟
	sim_region := begin_sim(game_state, game_memory)
	simulate(&sim_region)
	end_sim(game_state, &sim_region, game_memory)

	// 绘制
	// screen center reference, drawn before entities so debug anchors stay visible.
	draw_line_x(image_buffer.height / 2, image_buffer)
	draw_line_y(image_buffer.width / 2, image_buffer)

	// draw line on chunk corner
	for x in -10 ..< 10 {
		for y in -10 ..< 10 {
			chunkPivot := WorldPosition{V3i{i32(x), i32(y), 0}, 0}
			rel_pos := relative_pos(chunkPivot, game_state^.camera_pos)
			buffer_pos := rel_pos_to_buffer_pos(rel_pos, image_buffer)
			draw_dot(buffer_pos, image_buffer)
		}
	}

	entities := active_entities(game_state)
	for i in 0 ..< len(entities) {
		entity := &entities[i]
		// 下面计算把worldPos（米）转换为buffer使用的坐标（pixel）
		entity_pivot_buffer_pos := rel_pos_to_buffer_pos(
			relative_pos(entity.pos, game_state^.camera_pos),
			image_buffer,
		)

		// 玩家帧尺寸 or 一般实体尺寸（米→像素）
		entity_size_px := V2i {
			i32(meter_to_pixel(entity.size.x)),
			i32(meter_to_pixel(entity.size.y)),
		}
		top_left_buffer_pos := entity_top_left_from_pivot(entity_pivot_buffer_pos, entity_size_px)

		// 是否玩家
		is_player := entity.type == EntityType.Player

		switch entity.type {
		case .Player:
			draw_entity_animation(
				entity_pivot_buffer_pos,
				game_state.unit_animate,
				entity,
				image_buffer,
				time_span,
			)
			draw_entity_body_rectangle(entity_pivot_buffer_pos, entity_size_px, image_buffer)
		case .Wall:
			draw_entity_image(
				entity_pivot_buffer_pos,
				game_state^.rock_images[0],
				entity,
				image_buffer,
			)
		case .Tree:
		case .Enemy:
		case .Null:
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

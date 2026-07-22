package game

import "core:encoding/json" // 必须保留！用于注册 PNG 加载器
import "core:fmt"
import "core:image"
import "core:image/png"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:os"


V2 :: linalg.Vector2f32
V3 :: linalg.Vector3f32
V2i :: [2]i32
V3i :: [3]i32

SCALE :: f32(100.0)

meter_to_pixel_v1 :: proc(x: f32) -> i32 {
	return i32(x * SCALE)
}

meter_to_pixel_v2 :: proc(v: V2) -> V2i {
	return V2i{meter_to_pixel_v1(v.x), meter_to_pixel_v1(v.y)}
}

meter_to_pixel_v3 :: proc(v: V3) -> V3i {
	return V3i{meter_to_pixel_v1(v.x), meter_to_pixel_v1(v.y), meter_to_pixel_v1(v.z)}
}

meter_to_pixel :: proc {
	meter_to_pixel_v1,
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
	camera_pos:              WorldPosition,
	player:                  ^LowEntity,
	shark:                   ^LowEntity,
	entities:                [10000]LowEntity,
	entity_count:            u32,
	background:              ^image.Image,
	unit_animate_assets:     AseSpriteAsset,
	unit_animate:            Animation,
	harpoon_shark_assets:    AseSpriteAsset, // asset package parsed
	harpoon_shark_animation: Animation, // animation and config
	harpoon_sprite:          Sprite, // image and config
	tilemap1:                ^image.Image,
	game_map:                [tileMapY][tileMapX]V2i,
	rock_images:             [4]^image.Image,
	world:                   World,
}

CorppedImage :: struct {
	image:  ^image.Image,
	size:   V2i,
	offset: V2i,
}


wall_size :: f32(0.3)

ScreenPos :: V2

tileMapX :: 16
tileMapY :: 10

BufferRectangle :: struct {
	min: V2i,
	max: V2i,
}

Rectangle :: struct {
	min: V2,
	max: V2,
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
		game_state.camera_pos = WorldPosition{V3i{}, V3{}}
		// 地图
		for y in 0 ..< tileMapY {
			for x in 0 ..< tileMapX {
				if (x == 0 && y == 0) {
					game_state.game_map[y][x] = V2i{0, 0}
				} else if (x == tileMapX - 1 && y == 0) {
					game_state.game_map[y][x] = V2i{2, 0}
				} else if (x == 0 && y == tileMapY - 1) {
					game_state.game_map[y][x] = V2i{0, 2}
				} else if (x == tileMapX - 1 && y == tileMapY - 1) {
					game_state.game_map[y][x] = V2i{2, 2}
				} else if (x == 0) {
					game_state.game_map[y][x] = V2i{0, 1}
				} else if (x == tileMapX - 1) {
					game_state.game_map[y][x] = V2i{2, 1}
				} else if (y == 0) {
					game_state.game_map[y][x] = V2i{1, 0}
				} else if (y == tileMapY - 1) {
					game_state.game_map[y][x] = V2i{1, 2}
				} else {
					game_state.game_map[y][x] = V2i{1, 1}
				}
			}
		}
		// 初始化玩家
		// 以米为单位
		player := LowEntity {
			pos             = WorldPosition{V3i{0, 0, 0}, V3{0, 0, 0}},
			type            = EntityType.Player,
			size            = V2{0.6, 0.7},
			status          = EntityStatus.Idle,
			direction       = Direction.Forward,
			moveable        = true,
			hit_point_total = 3,
			hit_point_left  = 1,
		}
		add_entity(game_state, player, game_memory)
		game_state.player = &game_state.entities[0]

		//一个敌人
		shark := LowEntity {
			pos             = WorldPosition{V3i{0, 0, 0}, V3{-2, -2, 0}},
			type            = EntityType.Enemy,
			size            = V2{0.5, 0.6},
			status          = EntityStatus.Idle,
			direction       = Direction.Forward,
			moveable        = true,
			hit_point_total = 3,
			hit_point_left  = 3,
		}
		add_entity(game_state, shark, game_memory)
		game_state.shark = &game_state.entities[1]

		// 初始化地图
		for i in 1 ..< 7 {
			entity := LowEntity {
				pos  = WorldPosition{V3i{0, 0, 0}, V3{f32(i), 0, 0}},
				type = EntityType.Wall,
				size = V2{wall_size, wall_size},
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
			game_state.rock_images[i] = rock
		}

		// 加载asset
		// 载入地面
		tilemap1, err_load_tilemap1 := image.load_from_file(
			"resources/Terrain/Tilemap_color1.png",
			{},
			game_memory.temp_alloc, // 使用主程序传入的临时分配器
		)
		assert(err_load_tilemap1 == nil)
		game_state.tilemap1 = tilemap1

		// 载入单位动画
		game_state.unit_animate_assets = load_aseprite_assets(
			game_memory,
			game_state,
			"resources/Units/Warrior.png",
			"resources/Units/Warrior.json",
		)
		game_state.unit_animate = animation_from_assets(
			game_state.unit_animate_assets,
			"Warrior",
			V2i{95, 130},
		)

		game_state.harpoon_shark_assets = load_aseprite_assets(
			game_memory,
			game_state,
			"resources/Enemies/Harpoon Shark.png",
			"resources/Enemies/Harpoon Shark.json",
		)

		game_state.harpoon_shark_animation = animation_from_assets(
			game_state.harpoon_shark_assets,
			"Harpoon Shark",
			V2i{95, 130},
		)

		game_state.harpoon_sprite = sprite_from_assets(
			game_state.harpoon_shark_assets,
			"Harpoon Shark #Harpoon.aseprite",
			V2i{95, 130} + V2i{25, -45},
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

	// player 运动模拟
	player_rfd :: 10.0 //深蹲重量/体重

	is_moving := move.x != 0 || move.y != 0 || move.z != 0
	if (move.x != 0) {
		// 人物左右朝向
		game_state.player.direction = (move.x > 0 ? Direction.Forward : Direction.Backward)
	}

	//game_state.player.velocity = linalg.normalize(V2{move.x, move.y}) * player_speed
	game_state.player.acc = move.xy * player_rfd - game_state.player.velocity * 5 //摩擦力方向与速度相反

	is_attacking_1 := input.controllers[0].action_left.ended_down
	is_attacking_2 := input.controllers[0].action_down.ended_down
	next_status := next_status(is_moving, is_attacking_1, is_attacking_2)
	if (game_state.player.status != nil && game_state.player.status != next_status) {
		game_state.player.anim_frame_idx = 0
		game_state.player.anim_time = 0
	}
	game_state.player.status = next_status

	// shark运动输入
	shark_rfd :: 5
	distance_to_player := relative_pos(game_state.player.pos, game_state.shark.pos)
	shark_next_status :=
		math.abs(linalg.length(game_state.shark.velocity)) > 0.01 ? EntityStatus.Run : EntityStatus.Idle
	if linalg.length(distance_to_player) < 5 {
		//game_state.shark.acc = linalg.normalize(distance_to_player.xy) * shark_rfd - game_state.shark.velocity * 5
		shark_next_status = EntityStatus.Throw
		game_state.shark.direction =
			distance_to_player.x > 0 ? Direction.Forward : Direction.Backward
	} else {
		game_state.shark.acc = -game_state.shark.velocity * 5
	}
	if game_state.shark.status != nil && game_state.shark.status != shark_next_status {
		game_state.shark.anim_frame_idx = 0
		game_state.shark.anim_time = 0
	}
	game_state.shark.status = shark_next_status

	if game_state.shark.status == EntityStatus.Throw &&
	   game_state.shark.anim_frame_idx == 4 &&
	   game_state.shark.shark_harpoon_thrown == false {
		harpoon := LowEntity {
			pos      = world_pos_add(game_state.shark.pos, V3{0, 0.4, 0}),
			type     = EntityType.Weapon,
			size     = V2{0.2, 0.2},
			moveable = true,
			velocity = distance_to_player.xy,
			acc      = V2{0, -1},
		}
		add_entity(game_state, harpoon, game_memory)
		game_state.shark.shark_harpoon_thrown = true

	} else if game_state.shark.status == EntityStatus.Throw &&
	   game_state.shark.anim_frame_idx == 0 {
		game_state.shark.shark_harpoon_thrown = false
	}

	// camera追随player
	game_state.camera_pos = game_state.player.pos

	// debug坐标轴
	when ODIN_DEBUG {
		draw_line_x(image_buffer.height / 2, image_buffer)
		draw_line_y(image_buffer.width / 2, image_buffer)

		// debug chunk原点
		for x in -10 ..< 10 {
			for y in -10 ..< 10 {
				chunkPivot := WorldPosition{V3i{i32(x), i32(y), 0}, 0}
				rel_pos := relative_pos(chunkPivot, game_state.camera_pos)
				buffer_pos := rel_pos_to_buffer_pos(rel_pos, image_buffer)
				draw_dot(buffer_pos, image_buffer)
			}
		}
	}

	// 准备好初始条件（物体，初始速度）以后，开始区域计算模拟
	sim_region := begin_sim(game_state, game_memory)
	simulate(&sim_region, time_span)
	render_sim_region(&sim_region, image_buffer, game_state, time_span)
	when ODIN_DEBUG {
		draw_collision_debug(sim_region.debug_collision, image_buffer)
	}
	end_sim(game_state, &sim_region, game_memory)


}

@(export)
get_sound_samples: GetSoundSamplesProc : proc(
	game_memory: ^Memory,
	sound_buffer: ^SoundOutputBuffer,
) {
}

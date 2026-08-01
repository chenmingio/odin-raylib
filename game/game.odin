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

next_player_status :: proc(
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

PairwiseCollisionRule :: struct {
	entity_a:    u32,
	entity_b:    u32,
	can_collide: bool,
	next:        ^PairwiseCollisionRule,
}

GameState :: struct {
	camera_p:                  WorldPosition,
	player:                    u32,
	shark:                     u32,
	low_entities:              [10000]LowEntity,
	low_entity_count:          u32,
	free_entity_index_list:    [10000]u32,
	free_entity_index_count:   u32,
	background:                ^image.Image,
	unit_animate_assets:       AseSpriteAsset,
	unit_animate:              Animation,
	harpoon_shark_assets:      AseSpriteAsset, // asset package parsed
	harpoon_shark_animation:   Animation, // animation and config
	harpoon_sprite:            Sprite, // image and config
	tilemap1:                  ^image.Image,
	game_map:                  [tileMapY][tileMapX]V2i,
	rock_images:               [4]^image.Image,
	world:                     ^World,
	collision_rule_hash:       [256]^PairwiseCollisionRule,
	first_free_collision_rule: ^PairwiseCollisionRule,
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

Box :: struct {
	min: V3,
	max: V3,
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
	dt: f32,
)

GetSoundSamplesProc :: #type proc(game_memory: ^Memory, sound_buffer: ^SoundOutputBuffer)

@(export)
update_and_render: UpdateAndRenderProc : proc(
	game_memory: ^Memory,
	input: Input,
	image_buffer: OffScreenBuffer,
	dt: f32,
) {
	rand.reset(12345)
	// 之前以为不能premanent_storage直接拿来用，其实是可以的。
	// 只不过他是个slice，有元数据，要用raw_data来指向slice的data区域
	game_state := cast(^GameState)raw_data(game_memory.permanent_storage)
	if !game_memory.is_initialized {
		// 初始化工作
		// 设置初始相机位置
		game_state.camera_p = WorldPosition{V3i{}, V3{}}

		world := new(World, game_memory.perm_alloc)
		world.chunk_dim_in_meters = V3{10, 10, 10}
		game_state.world = world

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
			pos             = world_pos(world, V3i{0, 0, 0}, V3{0, 0, 0}),
			type            = EntityType.Player,
			size            = V2{0.6, 0.7},
			status          = EntityStatus.Idle,
			direction       = Direction.Forward,
			moveable        = true,
			hit_point_total = 3,
			hit_point_left  = 1,
			collides        = true,
		}
		game_state.player = add_low_entity(game_state, player, game_memory)

		//一个敌人
		new_shark := LowEntity {
			pos             = WorldPosition{V3i{0, 0, 0}, V3{-2, -2, 0}},
			type            = EntityType.Enemy,
			size            = V2{0.5, 0.6},
			status          = EntityStatus.Idle,
			direction       = Direction.Forward,
			moveable        = true,
			hit_point_total = 3,
			hit_point_left  = 3,
			collides        = true,
		}
		game_state.shark = add_low_entity(game_state, new_shark, game_memory)
		shark := get_low_entity(game_state, game_state.shark)

		harpoon := LowEntity {
			pos         = world_pos_add(game_state.world, new_shark.pos, V3{0, 0.4, 0.3}),
			type        = EntityType.Weapon,
			size        = V2{0.2, 0.2},
			moveable    = true,
			non_spatial = true,
			owner       = game_state.shark,
		}

		shark.weapon = add_low_entity(game_state, harpoon, game_memory)

		// 初始化地图
		for i in 1 ..< 7 {
			entity := LowEntity {
				pos      = WorldPosition{V3i{0, 0, 0}, V3{f32(i), 0, 0}},
				type     = EntityType.Wall,
				size     = V2{wall_size, wall_size},
				collides = true,
			}
			add_low_entity(game_state, entity, game_memory)
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

	player := get_low_entity(game_state, game_state.player)
	player.anim_elapsed_time += i32(dt * 1000)

	// player 运动模拟
	player_rfd :: 10.0 //深蹲重量/体重

	is_moving := move.x != 0 || move.y != 0 || move.z != 0
	if (move.x != 0) {
		// 人物左右朝向
		player.direction = (move.x > 0 ? Direction.Forward : Direction.Backward)
	}

	//player.velocity = linalg.normalize(V2{move.x, move.y}) * player_speed
	player.ddp = linalg.normalize0(move) * player_rfd - player.dp * 5 //摩擦力方向与速度相反

	is_attacking_1 := input.controllers[0].action_left.ended_down
	is_attacking_2 := input.controllers[0].action_down.ended_down
	next_status := next_player_status(is_moving, is_attacking_1, is_attacking_2)
	if (player.status != next_status) {
		player.anim_frame_idx = 0
		player.anim_elapsed_time = 0
	}
	player.status = next_status
	update_animate_frame_index(player, game_state.unit_animate)

	// shark运动输入
	shark := get_low_entity(game_state, game_state.shark)
	update_shark_state(shark, game_state, game_memory, dt)


	// camera追随player
	game_state.camera_p = player.pos

	// debug坐标轴
	when ODIN_DEBUG {
		draw_line_x(image_buffer.height / 2, image_buffer)
		draw_line_y(image_buffer.width / 2, image_buffer)

		// debug chunk原点
		for x in -10 ..< 10 {
			for y in -10 ..< 10 {
				chunkanchor := WorldPosition{V3i{i32(x), i32(y), 0}, 0}
				rel_pos := relative_pos(game_state.world, chunkanchor, game_state.camera_p)
				buffer_pos := rel_pos_to_buffer_pos(rel_pos, image_buffer)
				draw_dot(buffer_pos, image_buffer)
			}
		}
	}

	// 准备好初始条件（物体，初始速度）以后，开始区域计算模拟
	sim_region := begin_sim(game_state, game_memory, dt)
	simulate(&sim_region, dt, game_state, game_memory)
	render_sim_region(&sim_region, image_buffer, game_state, dt)
	when ODIN_DEBUG {
		draw_collision_debug(sim_region.debug_collision, image_buffer)
	}
	end_sim(game_state, &sim_region, game_memory)
}

update_shark_state :: proc(
	shark: ^LowEntity,
	game_state: ^GameState,
	game_memory: ^Memory,
	dt: f32,
) {
	harpoon := get_low_entity(game_state, shark.weapon)

	shark_rfd := 5

	player := get_low_entity(game_state, game_state.player)
	distance_to_player := relative_pos(game_state.world, player.pos, shark.pos)

	// 更新entity status
	// 默认Idel/Run
	//next_shark_status := math.abs(linalg.length(shark.velocity)) > 0.01 ? EntityStatus.Run : EntityStatus.Idle
	old_status := shark.status

	if shark.status == EntityStatus.Throw && shark.anim_elapsed_time > 700 {
		shark.status = EntityStatus.Idle
	}

	// 触发进入攻击状态(但是还不能扔出鱼叉)
	if shark.status == EntityStatus.Idle &&
	   harpoon.non_spatial &&
	   linalg.length(distance_to_player) < 4 {
		shark.status = EntityStatus.Throw
		// shark.shark_thrown_cooldown = 700
		shark.direction = distance_to_player.x > 0 ? Direction.Forward : Direction.Backward
	} else if shark.status == EntityStatus.Run {
		//shark.acc = linalg.normalize(distance_to_player.xy) * shark_rfd - shark.velocity * 5
		shark.ddp = -shark.dp * 5
	}

	if shark.status != old_status {
		shark.anim_frame_idx = 0
		shark.anim_elapsed_time = 0
	}

	// 到达攻击frame时，把non-spatial的武器装载状态，加入hash-chunk，设置为spatial
	if shark.status == EntityStatus.Throw &&
	   shark.anim_elapsed_time > 400 &&
	   harpoon.non_spatial == true {

		start_pos := world_pos_add(game_state.world, shark.pos, V3{0, 0.4, 0.5})
		target_pos := player.pos
		target_pos.offset.z = player.size.y / 2 //假设size.y/2不超过chunk size
		ds := relative_pos(game_state.world, target_pos, start_pos)
		t :: 0.8
		g :: V3{0, 0, -10}
		v0 := ds / t - (g * t) / 2

		harpoon.ddp = g
		harpoon.dp = v0
		harpoon.target_pos = target_pos
		harpoon.flight_time_remaining = t * 1000
		make_entity_spatial(harpoon, shark.weapon, start_pos, game_state, game_memory)

		add_collision_rule(
			game_state.shark,
			get_low_entity(game_state, game_state.shark).weapon,
			false,
			game_state,
			game_memory,
		)
	}

	// 想象frame time为1分钟，我们simulate和render是1分钟以后的世界。anim_elapsed_time应该在重置以后再加上1分钟
	shark.anim_elapsed_time += i32(dt * 1000)
	if harpoon.flight_time_remaining > 0 {
		harpoon.flight_time_remaining = math.max(0, harpoon.flight_time_remaining - i32(dt * 1000))
	}
	// 根据elapsed time更新frame index
	animation := game_state.harpoon_shark_animation
	update_animate_frame_index(shark, animation)
}

update_animate_frame_index :: proc(entity: ^LowEntity, animation: Animation) {
	clip := animation.clips[entity.status]
	clip_frames := clip.frames
	assert(len(clip_frames) > 0)

	elapsed_time :=
		(entity.status == EntityStatus.Throw) ? entity.anim_elapsed_time : entity.anim_elapsed_time % clip.total_duration

	acc: i32 = 0
	for idx in 0 ..< len(clip_frames) {
		frame := clip_frames[idx]
		if acc + frame.duration > elapsed_time {
			entity.anim_frame_idx = i32(idx)
			break
		} else {
			acc += frame.duration
		}
	}
}

collision_rule_hash :: proc(ety_a: u32, ety_b: u32) -> (u32, u32, u32) {
	min_ety_index := math.min(ety_a, ety_b)
	max_ety_index := math.max(ety_a, ety_b)
	hash := min_ety_index % 256
	return min_ety_index, max_ety_index, hash
}


get_collision_rule :: proc(ety_a: u32, ety_b: u32, state: ^GameState) -> ^PairwiseCollisionRule {
	min_ety_index, max_ety_index, hash := collision_rule_hash(ety_a, ety_b)
	bucket := state.collision_rule_hash[hash]
	for rule := bucket; rule != nil; rule = rule.next {
		if rule.entity_a == min_ety_index && rule.entity_b == max_ety_index {
			return rule
		}
	}
	return nil
}

// find a place in memory to store rule (free list or new memory location)
new_collison_rule :: proc(state: ^GameState, memory: ^Memory) -> ^PairwiseCollisionRule {
	result: ^PairwiseCollisionRule
	first_free := state.first_free_collision_rule
	if first_free != nil {
		state.first_free_collision_rule = first_free.next
		result = first_free
	} else {
		result = new(PairwiseCollisionRule, memory.perm_alloc)
	}
	return result
}

// 查重/幂等
add_collision_rule :: proc(
	ety_a: u32,
	ety_b: u32,
	can_collide: bool,
	state: ^GameState,
	memory: ^Memory,
) {
	min_ety_index, max_ety_index, hash := collision_rule_hash(ety_a, ety_b)
	// try to get rule if already exist
	test := get_collision_rule(ety_a, ety_b, state)
	if (test != nil) {
		test.can_collide = can_collide
		return
	}

	// get store location
	new_rule := new_collison_rule(state, memory)

	// add rule to bucket-rule-chain's head
	bucket: ^PairwiseCollisionRule = state.collision_rule_hash[hash]
	state.collision_rule_hash[hash] = new_rule

	new_rule^ = PairwiseCollisionRule{min_ety_index, max_ety_index, can_collide, bucket}
}

clear_collision_rules_for :: proc(ety: u32, state: ^GameState) {
	for hash in 0 ..< len(state.collision_rule_hash) {
		// 不常见的技巧
		// link指向hash的bucket的地址本身，而不是bucket地址内的rule地址。
		// link语义上我们把他指向“储存rule的容器”本身，而不是“rule”。
		// 这样可以解决prev的问题（link相当于prev的next，让你可以修改prev的next）
		// link^就是“容器内储存的rule”
		link := &state.collision_rule_hash[hash]
		for link^ != nil {
			rule := link^
			if rule.entity_a == ety || rule.entity_b == ety {
				// 把容器内存上“link里当前rule的下一个rule的地址”
				link^ = rule^.next
				// 清空内容
				rule^ = PairwiseCollisionRule{}

				// 回收rule到free list
				first_free := state.first_free_collision_rule
				state.first_free_collision_rule = rule
				rule.next = first_free
			} else {
				link = &link^.next
			}
		}
	}
}

@(export)
get_sound_samples: GetSoundSamplesProc : proc(
	game_memory: ^Memory,
	sound_buffer: ^SoundOutputBuffer,
) {
}

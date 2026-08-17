package game

import "core:fmt"
import "core:image"

WALL_SIZE :: f32(0.3)

initialize_game :: proc(game_state: ^GameState, game_memory: ^Memory) {
	game_state.camera_p = WorldPosition{V3i{}, V3{}}

	world := new(World, game_memory.perm_alloc)
	world.chunk_dim_in_meters = CHUNK_DIM_IN_METERS
	game_state.world = world

	add_demo_terrain(game_state, game_memory)

	// 初始化玩家
	player := LowEntity {
		pos             = world_pos(world, V3i{0, 0, 0}, V3{0, 0, 0}),
		type            = EntityType.Player,
		size            = V3{0.6, 0.6, 0.7},
		status          = EntityStatus.Idle,
		direction       = Direction.Forward,
		moveable        = true,
		hit_point_total = 3,
		hit_point_left  = 1,
		collides        = true,
	}
	game_state.player = add_low_entity(game_state, player, game_memory)

	// 初始化敌人
	new_shark := LowEntity {
		pos             = WorldPosition{V3i{0, 0, 0}, V3{-2, -2, 0}},
		type            = EntityType.Enemy,
		size            = V3{0.5, 0.5, 0.6},
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
		size        = V3{0.2, 0.2, 0.2},
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
			size     = V3{WALL_SIZE, WALL_SIZE, WALL_SIZE},
			collides = true,
		}
		add_low_entity(game_state, entity, game_memory)
	}

	for i in 0 ..< 4 {
		rock, err_load_rock := image.load_from_file(
			fmt.tprintf("resources/Decorations/Rocks/Rock%d.png", i + 1),
			{},
			game_memory.temp_alloc,
		)
		assert(err_load_rock == nil)
		game_state.rock_images[i] = rock
	}

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

	game_state.tilemap1 = load_tilemap_asset(
		game_memory,
		"resources/Terrain/Tilemap_color1.png",
		"resources/Terrain/Tilemap_color1.json",
	)

	game_memory.is_initialized = true
}

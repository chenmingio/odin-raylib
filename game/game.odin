package game

import "core:image"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"

V2 :: linalg.Vector2f32
V3 :: linalg.Vector3f32
V2i :: [2]i32
V3i :: [3]i32

meter_to_pixel_v1 :: proc(x: f32) -> i32 {
	return i32(x * PIXELS_PER_METER)
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
	tilemap1:                  TileMapAsset,
	rock_images:               [4]^image.Image,
	world:                     ^World,
	collision_rule_hash:       [256]^PairwiseCollisionRule,
	first_free_collision_rule: ^PairwiseCollisionRule,
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
	// permanent_storage 是 slice；raw_data 指向它的数据区域。
	game_state := cast(^GameState)raw_data(game_memory.permanent_storage)
	if !game_memory.is_initialized {
		initialize_game(game_state, game_memory)
	}

	draw_rectangle(V2i{0, 0}, V2i{image_buffer.width, image_buffer.height}, WATER, image_buffer)

	player := update_player(game_state, input, dt)
	shark := get_low_entity(game_state, game_state.shark)
	update_shark_state(shark, game_state, game_memory, dt)

	// camera追随player
	game_state.camera_p = player.pos

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

	sim_region := begin_sim(game_state, game_memory, dt)
	simulate(&sim_region, dt, game_state, game_memory)
	render_sim_region(&sim_region, image_buffer, game_state, dt)
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

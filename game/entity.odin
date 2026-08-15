package game

import "core:fmt"

EntityType :: enum {
	Null,
	Player,
	Enemy,
	Tree,
	Wall,
	Weapon,
	Tile,
}

TileType :: enum {
	Stair,
	Flat,
	Grass,
	Water,
}

TileArea :: struct {
	min:  V2i,
	size: V2i,
}

TerrainPatch :: struct {
	surface: TileVisual,
	area:    TileArea,
	level:   u8,
}

TileVisual :: enum u16 {
	Empty,
	Flat_Ground_Corner_Top_Left,
	Flat_Ground_Edge_Top,
	Flat_Ground_Corner_Top_Right,
	Flat_Ground_Narrow_Vertical_Top,
	Flat_Ground_Edge_Left,
	Flat_Ground_Center,
	Flat_Ground_Edge_Right,
	Flat_Ground_Narrow_Vertical_Middle,
	Flat_Ground_Corner_Bottom_Left,
	Flat_Ground_Edge_Bottom,
	Flat_Ground_Corner_Bottom_Right,
	Flat_Ground_Narrow_Vertical_Bottom,
	Flat_Ground_Narrow_Horizontal_Left,
	Flat_Ground_Narrow_Horizontal_Middle,
	Flat_Ground_Narrow_Horizontal_Right,
	Flat_Ground_Isolated,
	Stairs_Side_Left,
	Stairs_Side_Right,
	Elevated_Ground_Corner_Top_Left,
	Elevated_Ground_Edge_Top,
	Elevated_Ground_Corner_Top_Right,
	Elevated_Ground_Narrow_Vertical_Top,
	Elevated_Ground_Edge_Left,
	Elevated_Ground_Center,
	Elevated_Ground_Edge_Right,
	Elevated_Ground_Narrow_Vertical_Middle,
	Elevated_Ground_Cliff_Top_Left,
	Elevated_Ground_Cliff_Top,
	Elevated_Ground_Cliff_Top_Right,
	Elevated_Ground_Narrow_Vertical_Cliff_Top,
	Elevated_Ground_Cliff_Face_Left,
	Elevated_Ground_Cliff_Face,
	Elevated_Ground_Cliff_Face_Right,
	Elevated_Ground_Narrow_Vertical_Cliff_Face,
	Elevated_Ground_Narrow_Horizontal_Left,
	Elevated_Ground_Narrow_Horizontal_Middle,
	Elevated_Ground_Narrow_Horizontal_Right,
	Elevated_Ground_Isolated,
	Elevated_Ground_Narrow_Horizontal_Cliff_Left,
	Elevated_Ground_Narrow_Horizontal_Cliff_Middle,
	Elevated_Ground_Narrow_Horizontal_Cliff_Right,
	Elevated_Ground_Isolated_Cliff,
}

TileCell :: struct {
	visual: TileVisual,
	level:  i8,
}

EntityStatus :: enum {
	Idle,
	Walk,
	Run,
	Attack_1,
	Attack_2,
	Guard,
	Throw,
}

Direction :: enum {
	Forward,
	Backward,
}

status_names := [EntityStatus]string {
	.Idle     = "Idle",
	.Walk     = "Walk",
	.Run      = "Run",
	.Attack_1 = "Attack 1",
	.Attack_2 = "Attack 2",
	.Guard    = "Guard",
	.Throw    = "Throw",
}

entity_status_to_name :: proc(s: EntityStatus) -> string {
	return status_names[s]
}

name_to_entity_status :: proc(name: string) -> (EntityStatus, bool) {
	for s in EntityStatus {
		if status_names[s] == name {
			return s, true
		}
	}
	return EntityStatus.Idle, false
}

LowEntity :: struct {
	pos:                   WorldPosition,
	type:                  EntityType,
	size:                  V3,
	// render相关
	status:                EntityStatus,
	anim_frame_idx:        i32,
	anim_elapsed_time:     i32, // ms,当前frame花了多少时间，在切换frame以后清零
	direction:             Direction,
	// 碰撞相关
	moveable:              bool, //是否移动，比如墙就不能移动
	non_spatial:           bool, //是否在simRegion里参与模拟
	dp:                    V3, // derivative of p
	ddp:                   V3, // derivative of dp
	hit_point_total:       i32,
	hit_point_left:        i32,
	// 游戏逻辑相关
	owner:                 u32,
	weapon:                u32,
	target_pos:            WorldPosition,
	flight_time_remaining: i32, // ms
	attack_cooldown:       f32, // 目前用anim_elapsed_time代替
	collides:              bool, // false：纯装饰物：草、背景石头、特效、粒子。
}

SimEntity :: struct {
	low_entity:    ^LowEntity,
	storage_index: u32,
	p:             V3,
	to_remove:     bool,
	updatable:     bool,
}


// 获取活跃实体
// 目前是camera范围里10米的chunk
active_entities :: proc(state: ^GameState) -> []LowEntity {
	camera_pos_chunk := state.camera_p.chunkXYZ
	for x in camera_pos_chunk.x - 10 ..< camera_pos_chunk.x + 10 {
		for y in camera_pos_chunk.y - 5 ..< camera_pos_chunk.y + 5 {

		}
	}
	return state.low_entities[:state.low_entity_count]
}

// 添加entity-index到chunk HashMap里
add_entity_index_to_hash_chunk :: proc(
	state: ^GameState,
	memory: ^Memory,
	entity_index: u32,
	chunkPos: V3i,
) {
	chunk := get_world_chunk(state.world, chunkPos, memory)
	// 是否需要检查entity index已经存在chunk-block里了？

	// 如果正好满了，需要新建一个block作为first block放在顶部
	if chunk.first_block.entity_count == 16 {
		new_block := get_new_block(state.world, memory)
		new_block.next = chunk.first_block
		chunk.first_block = new_block
	}

	first_block := chunk.first_block
	first_block.entity_indexes[first_block.entity_count] = entity_index
	first_block.entity_count += 1
}

remove_entity_index_from_hash_chunk :: proc(
	low_entity_storage_index: u32,
	chunk: ^WorldChunk,
	state: ^GameState,
) {
	// chunk := get_world_chunk(state, chunk.chunkXYZ)
	// 找到含有entity index的block
	target_slot_idx: u32
	target_block: ^WorldEntityBlock
	last_slot_index: u32

	// invariant是“在first block里找空位，后面block都是满的“
	// 从first block里找最后一个补过去
	first_block := chunk.first_block
	assert(first_block != nil)
	assert(first_block.entity_count > 0)
	last_slot_storage_index_in_first_block :=
		first_block.entity_indexes[first_block.entity_count - 1]

	for block := chunk.first_block; block != nil; block = block.next {
		for idx in 0 ..< block.entity_count {
			if (block.entity_indexes[idx] == low_entity_storage_index) {
				block.entity_indexes[idx] = last_slot_storage_index_in_first_block
				first_block.entity_count -= 1
				break
			}
		}
	}

	// 如果first block空了，回收他
	if first_block.entity_count == 0 && first_block.next != nil {
		chunk.first_block = first_block.next
		first_block.next = nil
		free_block := state.world.first_free_entity_block
		state.world.first_free_entity_block = first_block
		first_block.next = free_block
	}
}

remove_entity_from_entity_list :: proc(state: ^GameState, index: u32) {
	state.free_entity_index_list[state.free_entity_index_count] = index
	state.free_entity_index_count += 1
}


add_low_entity :: proc(state: ^GameState, entity: LowEntity, memory: ^Memory) -> u32 {
	// get entity index
	entity_index: u32
	if state.free_entity_index_count > 0 {
		entity_index = state.free_entity_index_list[state.free_entity_index_count - 1]
		state.free_entity_index_count -= 1
	} else {
		entity_index = state.low_entity_count
		state.low_entity_count += 1
	}

	stored_entity := entity
	if !entity.non_spatial {
		stored_entity.pos = canonicalize(state.world, stored_entity.pos)
	}
	state.low_entities[entity_index] = stored_entity

	// 添加entity chunk index
	if !stored_entity.non_spatial {
		add_entity_index_to_hash_chunk(state, memory, entity_index, stored_entity.pos.chunkXYZ)
	}
	return entity_index
}

get_low_entity :: proc(state: ^GameState, index: u32) -> ^LowEntity {
	return &state.low_entities[index]
}

flat_ground_visual_for_tile :: proc(area: TileArea, tile_pos: V2i) -> TileVisual {
	assert(area.size.x > 0 && area.size.y > 0)
	max_pos := area.min + area.size - 1
	assert(
		tile_pos.x >= area.min.x && tile_pos.x <= max_pos.x &&
			tile_pos.y >= area.min.y && tile_pos.y <= max_pos.y,
	)

	is_left := tile_pos.x == area.min.x
	is_right := tile_pos.x == max_pos.x
	is_bottom := tile_pos.y == area.min.y
	is_top := tile_pos.y == max_pos.y

	if area.size.x == 1 && area.size.y == 1 {
		return .Flat_Ground_Isolated
	}
	if area.size.x == 1 {
		if is_top {return .Flat_Ground_Narrow_Vertical_Top}
		if is_bottom {return .Flat_Ground_Narrow_Vertical_Bottom}
		return .Flat_Ground_Narrow_Vertical_Middle
	}
	if area.size.y == 1 {
		if is_left {return .Flat_Ground_Narrow_Horizontal_Left}
		if is_right {return .Flat_Ground_Narrow_Horizontal_Right}
		return .Flat_Ground_Narrow_Horizontal_Middle
	}

	if is_top {
		if is_left {return .Flat_Ground_Corner_Top_Left}
		if is_right {return .Flat_Ground_Corner_Top_Right}
		return .Flat_Ground_Edge_Top
	}
	if is_bottom {
		if is_left {return .Flat_Ground_Corner_Bottom_Left}
		if is_right {return .Flat_Ground_Corner_Bottom_Right}
		return .Flat_Ground_Edge_Bottom
	}
	if is_left {return .Flat_Ground_Edge_Left}
	if is_right {return .Flat_Ground_Edge_Right}
	return .Flat_Ground_Center
}

add_tile_grass :: proc(world: ^World, memory: ^Memory, area: TileArea, level: u8) {
	assert(area.size.x > 0 && area.size.y > 0)
	_ = level // tile_map 改成 TileCell 后再保存高度。

	for y in area.min.y ..< area.min.y + area.size.y {
		for x in area.min.x ..< area.min.x + area.size.x {
			chunk_x, local_x := tile_axis_to_chunk(x, CHUNK_TILE_DIM.x)
			chunk_y, local_y := tile_axis_to_chunk(y, CHUNK_TILE_DIM.y)
			chunk := get_world_chunk(world, V3i{chunk_x, chunk_y, 0}, memory)
			chunk.tile_map[local_y][local_x] = flat_ground_visual_for_tile(area, V2i{x, y})
		}
	}
}

package game

import "core:fmt"

EntityType :: enum {
	Null,
	Player,
	Enemy,
	Tree,
	Wall,
}

EntityStatus :: enum {
	Null,
	Idle,
	Walk,
	Run,
	Attack_1,
	Attack_2,
	Guard,
}

Direction :: enum {
	Forward,
	Backward,
}

status_names := [EntityStatus]string {
	.Null     = "Null",
	.Idle     = "Idle",
	.Walk     = "Walk",
	.Run      = "Run",
	.Attack_1 = "Attack 1",
	.Attack_2 = "Attack 2",
	.Guard    = "Guard",
}

entity_status_to_name :: proc(s: EntityStatus) -> string {
	return status_names[s]
}

name_to_entity_status :: proc(name: string) -> EntityStatus {
	for s in EntityStatus {
		if status_names[s] == name {
			return s
		}
	}
	return .Null
}

LowEntity :: struct {
	pos:            WorldPosition,
	type:           EntityType,
	size:           V2,
	status:         EntityStatus,
	anim_frame_idx: i32,
	anim_time:      i32, // ms
	direction:      Direction,
}

HighEntity :: struct {
	low_entity:               ^LowEntity,
	low_entity_storage_index: u32,
	rel_pos:                  V3,
}


// 辅助函数：获取活跃实体的 slice
active_entities :: proc(state: ^GameState) -> []LowEntity {
	return state.entities[:state.entity_count]
}

// 添加entity-index到chunk HashMap里
add_entity_index_to_hash_chunk :: proc(
	state: ^GameState,
	memory: ^Memory,
	entity_index: u32,
	chunkPos: V3i,
) {
	chunk := get_world_chunk(state, chunkPos, memory)

	// 如果正好满了，需要新建一个block作为first block放在顶部
	if chunk.first_block.entity_count == 16 {
		new_block := get_new_block(&state.world, memory)
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
	chunk := get_world_chunk(state, chunk.chunkXYZ)
	// 找到含有entity index的block
	target_slot_idx: u32
	target_block: ^WorldEntityBlock
	last_slot_index: u32

	// invariant是“在first block里找空位，后面block都是满的“
	// 从first block里找最后一个补过去
	first_block := chunk.first_block
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
	if first_block.entity_count == 0 {
		chunk.first_block = first_block.next
		first_block.next = nil
		free_block := state.world.first_free_entity_block
		state.world.first_free_entity_block = first_block
		first_block.next = free_block
	}
}

add_entity :: proc(state: ^GameState, entity: LowEntity, memory: ^Memory) {
	// 添加entity数据储存
	assert(state.entity_count < len(state.entities))
	state.entities[state.entity_count] = entity
	// 添加entity index
	add_entity_index_to_hash_chunk(state, memory, state.entity_count, entity.pos.chunkXYZ)
	state.entity_count += 1
}

// 辅助函数：删除实体（交换到末尾然后删除）
remove_entity :: proc(state: ^GameState, index: u32) {
	assert(index < state.entity_count)
	// 把最后一个实体移到被删除的位置
	state.entities[index] = state.entities[state.entity_count - 1]
	state.entity_count -= 1
}

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
	low_entity: ^LowEntity,
	rel_pos:    V3,
}


// 辅助函数：获取活跃实体的 slice
active_entities :: proc(state: ^GameState) -> []LowEntity {
	return state.entities[:state.entity_count]
}

// 添加实体
add_entity :: proc(state: ^GameState, entity: LowEntity, memory: ^Memory) {
	// 添加entity储存
	assert(state.entity_count < len(state.entities))
	state.entities[state.entity_count] = entity
	state.entity_count += 1
	// 添加index到chunk中
	chunk := get_world_chunk(state, entity.pos.chunkXYZ, memory)
	block := chunk.first_block
	for block.next != nil {
		block = block.next
	}

	// 如果正好满了，需要新建一个block
	if block.entity_indexes[len(block.entity_indexes) - 1] != 0 {
		new_block := new(WorldEntityBlock, memory.perm_alloc)
		block.next = new_block
		block = new_block
	}

	for &slot in block.entity_indexes {
		if slot == 0 {
			slot = state.entity_count - 1
			break
		}
	}
}

// 辅助函数：删除实体（交换到末尾然后删除）
remove_entity :: proc(state: ^GameState, index: u32) {
	assert(index < state.entity_count)
	// 把最后一个实体移到被删除的位置
	state.entities[index] = state.entities[state.entity_count - 1]
	state.entity_count -= 1
}

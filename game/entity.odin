package game

import "core:fmt"

EntityType :: enum {
	Null,
	Player,
	Enemy,
	Tree,
	Wall,
}

Entity :: struct {
	pos:  WorldPos,
	type: EntityType,
	size: V2,
}


// 辅助函数：获取活跃实体的 slice
active_entities :: proc(state: ^GameState) -> []Entity {
	return state.entities[:state.entity_count]
}

// 辅助函数：添加实体
add_entity :: proc(state: ^GameState, entity: Entity) {
	assert(state.entity_count < len(state.entities))
	state.entities[state.entity_count] = entity
	state.entity_count += 1
}

// 辅助函数：删除实体（交换到末尾然后删除）
remove_entity :: proc(state: ^GameState, index: u32) {
	assert(index < state.entity_count)
	// 把最后一个实体移到被删除的位置
	state.entities[index] = state.entities[state.entity_count - 1]
	state.entity_count -= 1
}

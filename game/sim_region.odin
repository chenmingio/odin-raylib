package game

import "core:fmt"

SimRegion :: struct {
	high_entities:     [4096]HighEntity, // 复制数据（而不是id或者指针），方便模拟和修改
	high_entity_count: u32,
	space:             Rectangle,
}

// 加载相关entity到high区
begin_sim :: proc(state: ^GameState, memory: ^Memory) -> SimRegion {
	result := SimRegion{}
	// 根据camera的坐标找到chunk
	for x in state.camera_pos.chunkXYZ.x ..< state.camera_pos.chunkXYZ.x + 1 {
		for y in state.camera_pos.chunkXYZ.y ..< state.camera_pos.chunkXYZ.y + 1 {
			for z in state.camera_pos.chunkXYZ.z ..< state.camera_pos.chunkXYZ.z + 1 {
				chunk := get_world_chunk(state, V3i{x, y, z}, memory)
				assert(chunk != nil)

				// copy entity values into SimRegion
				for block := chunk.first_block; block != nil; block = block.next {
					for low_entity_storage_id in block.entity_indexes[:block.entity_count] {
						low_entity := &state.entities[low_entity_storage_id]
						high_entity := HighEntity {
							low_entity               = low_entity,
							low_entity_storage_index = low_entity_storage_id,
							rel_pos                  = relative_pos(
								low_entity.pos,
								state.camera_pos,
							),
						}
						result.high_entities[result.high_entity_count] = high_entity

						assert(result.high_entity_count < len(result.high_entities))
						result.high_entity_count += 1
					}
				}
			}
		}
	}
	return result
}

shouldCollide :: proc(ety_a: ^HighEntity, ety_b: ^HighEntity) -> bool {
	return true
}

collide :: proc(ety_a: ^HighEntity, ety_b: ^HighEntity) {
	// Implement collision logic here
}

simulate :: proc(sim_region: ^SimRegion) {
	entities := sim_region.high_entities[:sim_region.high_entity_count]

	for i in 0 ..< len(entities) {
		for j in i + 1 ..< len(entities) {
			ety_a := &entities[i]
			ety_b := &entities[j]
			if shouldCollide(ety_a, ety_b) {
				collide(ety_a, ety_b)
			}
		}
	}
}

// 模拟的浮点坐标转换为low entity的低精度坐标
world_pos_add_rel :: proc(rel_pos: [3]f32, camera_pos: WorldPosition) -> WorldPosition {
	result := camera_pos
	result.offset.x += rel_pos.x
	result.offset.y += rel_pos.y
	result.offset.z += rel_pos.z

	return canonicalize(result)
}

// 重新放置low entity的chunk位置
reIndex :: proc(
	low_entity: ^LowEntity,
	low_entity_storage_index: u32,
	new_pos: WorldPosition,
	state: ^GameState,
	memory: ^Memory,
) {
	// 同一个chunk里不用变
	if (hashChunk(low_entity.pos.chunkXYZ) == hashChunk(new_pos.chunkXYZ)) {
		return
	}

	oldPos := low_entity.pos
	old_chunk := get_world_chunk(state, oldPos.chunkXYZ, memory)
	assert(old_chunk != nil)

	remove_entity_index_from_hash_chunk(low_entity_storage_index, old_chunk, state)

	add_entity_index_to_hash_chunk(state, memory, low_entity_storage_index, new_pos.chunkXYZ)
}

// 把计算好的high entity对应的状态（目前是未知）更新回原来的low entity
end_sim :: proc(state: ^GameState, sim_region: ^SimRegion, memory: ^Memory) {
	high_entities := sim_region.high_entities[:sim_region.high_entity_count]
	for high_entity in high_entities {
		new_pos := world_pos_add_rel(high_entity.rel_pos, state.camera_pos)
		reIndex(
			high_entity.low_entity,
			high_entity.low_entity_storage_index,
			new_pos,
			state,
			memory,
		)
	}
}

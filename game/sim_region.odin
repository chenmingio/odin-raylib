package game

import "core:fmt"

SimRegion :: struct {
	high_entities:     [4096]HighEntity, // 复制数据（而不是id或者指针），方便模拟和修改
	high_entity_count: u32,
	space:             Rectangle,
}

begin_sim :: proc(state: ^GameState, memory: ^Memory) -> SimRegion {
	result := SimRegion{}
	// which chunks?
	for x in state.camera_pos.chunkXYZ.x ..< state.camera_pos.chunkXYZ.x + 1 {
		for y in state.camera_pos.chunkXYZ.y ..< state.camera_pos.chunkXYZ.y + 1 {
			for z in state.camera_pos.chunkXYZ.z ..< state.camera_pos.chunkXYZ.z + 1 {
				// load chunk data
				chunk := get_world_chunk(state, V3i{x, y, z}, memory)
				assert(chunk != nil)

				// copy entity values into SimRegion
				for block := chunk.first_block; block != nil; block = block.next {
					for entity_id in block.entity_indexes[:block.entity_count] {
						low_entity := &state.entities[entity_id]
						high_entity := HighEntity {
							low_entity = low_entity,
							rel_pos    = relative_pos(low_entity.pos, state.camera_pos),
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


end_sim :: proc(state: ^GameState, sim_region: ^SimRegion) {
	high_entities := sim_region.high_entities[:sim_region.high_entity_count]

	for high_entity in high_entities {
		new_pos := relative_world_pos(high_entity.rel_pos, state.camera_pos)
		high_entity.low_entity.pos = new_pos
		reIndex(high_entity.low_entity) // 调整index
		// Implement end simulation logic here
	}
}

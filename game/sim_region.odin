package game

import "core:fmt"

SimRegion :: struct {
	entities: [4096]Entity, // 复制数据（而不是id或者指针），方便模拟和修改
	entity_count: u32,
	space:    Rectangle,
}

begin_sim :: proc(state: ^GameState, memory: Memory) -> SimRegion {
	result := SimRegion {}
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
						entity := state.entities[entity_id]
						result.entities[result.entity_count] = entity

						assert(result.entity_count < len(result.entities))
						result.entity_count += 1
					}
			}
		}
	}
	return result
}

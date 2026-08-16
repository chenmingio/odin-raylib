package game

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
	// 找到含有entity index的block
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

make_entity_spatial :: proc(
	ety: ^LowEntity,
	ety_index: u32,
	pos: WorldPosition,
	game_state: ^GameState,
	game_memory: ^Memory,
) {
	canonical_pos := canonicalize(game_state.world, pos)
	ety.pos = canonical_pos
	assert(ety.non_spatial == true)
	ety.non_spatial = false
	add_entity_index_to_hash_chunk(game_state, game_memory, ety_index, canonical_pos.chunkXYZ)
}

// 模拟的浮点坐标转换为low entity的低精度坐标
map_into_chunk_space :: proc(
	world: ^World,
	rel_pos: [3]f32,
	camera_pos: WorldPosition,
) -> WorldPosition {
	result := camera_pos
	result.offset.x += rel_pos.x
	result.offset.y += rel_pos.y
	result.offset.z += rel_pos.z

	return canonicalize(world, result)
}

// 重新放置low entity的chunk位置
change_entity_location :: proc(
	low_entity: ^LowEntity,
	low_entity_storage_index: u32,
	new_pos: WorldPosition,
	state: ^GameState,
	memory: ^Memory,
	remove: bool,
) {
	oldPos := low_entity.pos
	old_chunk := get_world_chunk(state.world, oldPos.chunkXYZ, memory)
	assert(old_chunk != nil)

	if (remove) {
		remove_entity_index_from_hash_chunk(low_entity_storage_index, old_chunk, state)
		return
	}

	// 同一个chunk里不用变
	if (low_entity.pos.chunkXYZ == new_pos.chunkXYZ) {
		return
	}

	remove_entity_index_from_hash_chunk(low_entity_storage_index, old_chunk, state)
	add_entity_index_to_hash_chunk(state, memory, low_entity_storage_index, new_pos.chunkXYZ)
}

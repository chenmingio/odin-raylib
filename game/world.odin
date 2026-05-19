package game

WorldPosition :: struct {
	chunkXYZ: V3i,
	offset:   V3,
}

WorldEntityBlock :: struct {
	entity_indexes: [16]u32,
	entity_count:   u32,
	next:           ^WorldEntityBlock,
}

WorldChunk :: struct {
	first_block:  ^WorldEntityBlock,
	// chunk hash里，同一个bucket里的下一个chunk
	next_in_hash: ^WorldChunk,
	chunkXYZ:     V3i,
}

World :: struct {
	tileSideInMeters:    f32,
	chunk_dim_in_meters: V3i,
	chunk_hash:          [4096]^WorldChunk,
	first_free:          ^WorldEntityBlock,
}

chunkSideInMeters :: 30

canonicalize :: proc(p: WorldPosition) -> WorldPosition {
	pos := p

	d := V3i {
		i32(pos.offset.x) / chunkSideInMeters,
		i32(pos.offset.y) / chunkSideInMeters,
		i32(pos.offset.z) / chunkSideInMeters,
	}

	pos.chunkXYZ += d

	pos.offset.x -= f32(d[0] * chunkSideInMeters)
	pos.offset.y -= f32(d[1] * chunkSideInMeters)
	pos.offset.z -= f32(d[2] * chunkSideInMeters)

	assert(abs(pos.offset.x) < chunkSideInMeters)
	assert(abs(pos.offset.y) < chunkSideInMeters)
	assert(abs(pos.offset.z) < chunkSideInMeters)

	return pos
}

relative_pos :: proc(p1, p2: WorldPosition) -> V3 {
	di := p1.chunkXYZ - p2.chunkXYZ // [3]i32
	df := V3{f32(di.x), f32(di.y), f32(di.z)} // Vector3f32
	return df + p1.offset - p2.offset
}

world_pos_add :: proc(p: WorldPosition, d: V3) -> WorldPosition {
	p := p
	p.offset += d
	return canonicalize(p)
}

hashChunk :: proc(xyz: V3i) -> i32 {
	return xyz.x * 19 + xyz.y * 7 + xyz.z * 3
}

get_world_chunk :: proc(
	state: ^GameState,
	chunkXYZ: V3i,
	memory: Maybe(^Memory) = nil,
) -> ^WorldChunk {
	h := hashChunk(chunkXYZ)
	head := state.world.chunk_hash[h]
	// 如果通过链表找到符合XYZ的chunk，直接返回
	for c := head; c != nil; c = c.next_in_hash {
		if c.chunkXYZ == chunkXYZ {
			return c
		}
	}

	// 不然就创建一个新chunk
	mem, ok := memory.?
	if !ok {
		panic("Chunk not found and no memory provided for creation")
	}
	new_chunk := new(WorldChunk, mem.perm_alloc)
	new_block := new(WorldEntityBlock, mem.perm_alloc)
	new_chunk^ = WorldChunk{new_block, nil, chunkXYZ}

	new_chunk.next_in_hash = state.world.chunk_hash[h]
	state.world.chunk_hash[h] = new_chunk
	return new_chunk
}

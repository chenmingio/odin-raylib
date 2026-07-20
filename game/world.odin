package game

import "core:math"
WorldPosition :: struct {
	chunkXYZ: V3i,
	offset:   V3,
}

WorldEntityBlock :: struct {
	entity_indexes: [16]u32,
	entity_count:   u32, // 使用count方便slice操作。如果用0来控制结尾，操作更复杂，不如多一个index直观。
	next:           ^WorldEntityBlock,
}

WorldChunk :: struct {
	first_block:  ^WorldEntityBlock, // block是固定容量的储存容器，链表结构，动态创建，用freeList回收不用的
	chunkXYZ:     V3i,
	next_in_hash: ^WorldChunk, // chunk hash里同一个bucket里的下一个chunk
}

World :: struct {
	tileSideInMeters:        f32,
	chunk_dim_in_meters:     V3i,
	chunk_hash:              [4096]^WorldChunk, // 4096个桶，每个桶里面是worldChunk的链表，每个chunk的xyz不同
	first_free_entity_block: ^WorldEntityBlock,
}

chunkSideInMeters :: 10
// 目前使用offset坐标原点在chunk的左下角的关系。offset区间为[0, chunkSide)
// Casey的设计，rel的原点在chunk中点

canonicalize_axis :: proc(chunk: i32, offset: f32) -> (i32, f32) {
	// 获取chunk部分，
	// 10.5/10.0 = 1.05 -> floor to 1
	// -10.5/10.0 = -1.05 -> floor to -2
	chunk_delta := i32(math.floor(offset / chunkSideInMeters))

	new_chunk := chunk + chunk_delta
	new_offset := offset - f32(chunk_delta) * chunkSideInMeters

	if (new_offset + eps) > f32(chunkSideInMeters) {
		new_chunk += 1
		new_offset = 0
	}

	assert(new_offset >= 0)
	assert(new_offset < chunkSideInMeters)
	return new_chunk, new_offset
}

canonicalize :: proc(p: WorldPosition) -> WorldPosition {
	xc, xo := canonicalize_axis(p.chunkXYZ.x, p.offset.x)
	yc, yo := canonicalize_axis(p.chunkXYZ.y, p.offset.y)
	zc, zo := canonicalize_axis(p.chunkXYZ.z, p.offset.z)

	return WorldPosition{V3i{xc, yc, zc}, V3{xo, yo, zo}}
}

relative_pos :: proc(p1, p2: WorldPosition) -> V3 {
	delta_chunk := p1.chunkXYZ - p2.chunkXYZ
	delta_offset :=
		V3{f32(delta_chunk.x), f32(delta_chunk.y), f32(delta_chunk.z)} * chunkSideInMeters
	return delta_offset + p1.offset - p2.offset
}

world_pos_add :: proc(p: WorldPosition, d: V3) -> WorldPosition {
	p := p
	p.offset += d
	return canonicalize(p)
}

hashChunk :: proc(xyz: V3i) -> i32 {
	return (xyz.x * 19 + xyz.y * 7 + xyz.z * 3) %% 4096
}

// 从freelist里找一个block，如果没有free再动态分配一个block
get_new_block :: proc(world: ^World, memory: ^Memory) -> ^WorldEntityBlock {
	first_free := world.first_free_entity_block
	if (first_free == nil) {
		return new(WorldEntityBlock, memory.perm_alloc)
	} else {
		next_free := first_free.next
		world.first_free_entity_block = next_free
		first_free.next = nil
		return first_free
	}

}

// 纯读取xyz所在的chunk：不传memory
// 获取xyz的chunk用来储存，必要时创建新的chunk/block：需要传memory
get_world_chunk :: proc(state: ^GameState, chunkXYZ: V3i, memory: ^Memory = nil) -> ^WorldChunk {
	h := hashChunk(chunkXYZ)
	head := state.world.chunk_hash[h]
	// 如果通过链表找到符合XYZ的chunk，直接返回
	for c := head; c != nil; c = c.next_in_hash {
		if c.chunkXYZ == chunkXYZ {
			assert(c.first_block != nil)
			return c
		}
	}

	// 需要新建chunk的情况
	assert(memory != nil, "memory should be available for chunk creation")
	new_chunk := new(WorldChunk, memory.perm_alloc)
	new_block := get_new_block(&state.world, memory)
	new_chunk^ = WorldChunk{new_block, chunkXYZ, nil}

	new_chunk.next_in_hash = state.world.chunk_hash[h]
	state.world.chunk_hash[h] = new_chunk
	return new_chunk
}

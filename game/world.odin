package game

import "core:math"

CHUNK_TILE_DIM :: V2i{10, 10} // chunk的xy由几个tile组成
CHUNK_HEIGHT_METERS :: f32(10) // chunk的z的高度（目前不参与tile）

RENDER_WIDTH_IN_PIXELS :: i32(1280)
RENDER_HEIGHT_IN_PIXELS :: i32(720)
PIXELS_PER_METER :: f32(64)

TILE_SIDE_IN_METERS :: f32(1)

CAMERA_VIEW_SPAN_X_IN_METERS :: f32(RENDER_WIDTH_IN_PIXELS) / PIXELS_PER_METER
CAMERA_VIEW_SPAN_Y_IN_METERS :: f32(RENDER_HEIGHT_IN_PIXELS) / PIXELS_PER_METER
// Z 不是由屏幕尺寸推导的，而是需要同时模拟的游戏世界高度。
CAMERA_VIEW_SPAN_Z_IN_METERS :: f32(4.2)

CHUNK_DIM_IN_METERS :: V3 {
	f32(CHUNK_TILE_DIM.x) * TILE_SIDE_IN_METERS,
	f32(CHUNK_TILE_DIM.y) * TILE_SIDE_IN_METERS,
	CHUNK_HEIGHT_METERS,
}

tile_axis_to_chunk :: proc(tile: i32, chunk_tile_count: i32) -> (chunk, local: i32) {
	local = tile %% chunk_tile_count
	chunk = (tile - local) / chunk_tile_count
	return
}


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
	tile_map:     [CHUNK_TILE_DIM.y][CHUNK_TILE_DIM.x]TileVisual,
}

World :: struct {
	chunk_dim_in_meters:     V3,
	chunk_hash:              [4096]^WorldChunk, // 4096个桶，每个桶里面是worldChunk的链表，每个chunk的xyz不同
	first_free_entity_block: ^WorldEntityBlock,
}

world_pos :: proc(world: ^World, chunk_xyz: V3i, offset: V3) -> WorldPosition {
	return canonicalize(world, WorldPosition{chunk_xyz, offset})
}

// 目前使用offset坐标原点在chunk的左下角的关系。offset区间为[0, chunkSide)
// Casey的设计，rel的原点在chunk中点

is_canonical :: proc(world: ^World, p: WorldPosition) -> bool {
	chunk_dim_in_meters := world.chunk_dim_in_meters
	return(
		p.offset.x >= 0 &&
		p.offset.x < chunk_dim_in_meters.x &&
		p.offset.y >= 0 &&
		p.offset.y < chunk_dim_in_meters.y &&
		p.offset.z >= 0 &&
		p.offset.z < chunk_dim_in_meters.z \
	)
}

canonicalize_axis :: proc(chunk: i32, offset: f32, chunk_side_in_meters: f32) -> (i32, f32) {

	// 获取chunk部分，
	// 10.5/10.0 = 1.05 -> floor to 1
	// -10.5/10.0 = -1.05 -> floor to -2
	chunk_delta := i32(math.floor(offset / chunk_side_in_meters))

	new_chunk := chunk + chunk_delta
	new_offset := offset - f32(chunk_delta) * chunk_side_in_meters

	if (new_offset + SIM_EPS) > f32(chunk_side_in_meters) {
		new_chunk += 1
		new_offset = 0
	}

	assert(new_offset >= 0)
	assert(new_offset < chunk_side_in_meters)
	return new_chunk, new_offset
}

canonicalize :: proc(world: ^World, p: WorldPosition) -> WorldPosition {
	chunk_dim_in_meters := world.chunk_dim_in_meters
	xc, xo := canonicalize_axis(p.chunkXYZ.x, p.offset.x, chunk_dim_in_meters.x)
	yc, yo := canonicalize_axis(p.chunkXYZ.y, p.offset.y, chunk_dim_in_meters.y)
	zc, zo := canonicalize_axis(p.chunkXYZ.z, p.offset.z, chunk_dim_in_meters.z)

	return WorldPosition{V3i{xc, yc, zc}, V3{xo, yo, zo}}
}

relative_pos :: proc(world: ^World, p1, p2: WorldPosition) -> V3 {
	chunk_dim_in_meters := world.chunk_dim_in_meters
	delta_chunk := p1.chunkXYZ - p2.chunkXYZ
	delta_offset := V3 {
		f32(delta_chunk.x) * chunk_dim_in_meters.x,
		f32(delta_chunk.y) * chunk_dim_in_meters.y,
		f32(delta_chunk.z) * chunk_dim_in_meters.z,
	}
	return delta_offset + p1.offset - p2.offset
}

world_pos_add :: proc(world: ^World, p: WorldPosition, d: V3) -> WorldPosition {
	p := p
	p.offset += d
	return canonicalize(world, p)
}

world_pos_minus :: proc(world: ^World, p: WorldPosition, d: V3) -> WorldPosition {
	return world_pos_add(world, p, -d)
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
get_world_chunk :: proc(world: ^World, chunkXYZ: V3i, memory: ^Memory = nil) -> ^WorldChunk {
	h := hashChunk(chunkXYZ)
	head := world.chunk_hash[h]
	// 如果通过链表找到符合XYZ的chunk，直接返回
	for c := head; c != nil; c = c.next_in_hash {
		if c.chunkXYZ == chunkXYZ {
			assert(c.first_block != nil)
			return c // 直接返回参数
		}
	}

	// 需要新建chunk的情况
	assert(memory != nil, "memory should be available for chunk creation")
	new_chunk := new(WorldChunk, memory.perm_alloc)
	new_block := get_new_block(world, memory)
	new_chunk^ = WorldChunk{new_block, chunkXYZ, nil, {}}

	new_chunk.next_in_hash = world.chunk_hash[h]
	world.chunk_hash[h] = new_chunk
	return new_chunk
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

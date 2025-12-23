package game

WorldPos :: struct {
	chunk:  V3i,
	offset: V3,
}

World :: struct {
	tileSideInMeters:  f32,
	chunkSideInMeters: f32,
}

ChunkPos :: V3i

canonicalize :: proc(p: WorldPos) -> WorldPos {
	pos := p

	// 1) 取相对位移的整数部分（向零截断）
	d := V3i{i32(pos.offset.x), i32(pos.offset.y), i32(pos.offset.z)}

	// 2) 整数部分进位到块坐标
	pos.chunk += d

	// 3) 从相对位移里扣掉整数部分
	pos.offset.x -= f32(d[0])
	pos.offset.y -= f32(d[1])
	pos.offset.z -= f32(d[2])

	return pos
}

relative_pos :: proc(p1, p2: WorldPos) -> V3 {
	di := p1.chunk - p2.chunk // [3]i32
	df := V3{f32(di.x), f32(di.y), f32(di.z)} // Vector3f32
	return df + p1.offset - p2.offset
}

world_pos_add :: proc(p: WorldPos, d: V3) -> WorldPos {
	p := p
	p.offset += d
	return canonicalize(p)
}

单链表算法逻辑

逻辑
循环链条直到（target符合目标或者target为nil）
第一次也能包含在这里

第一次explict：

If first-is-nil {
	create one}
Else {

	while (target is not nil) {
		if target.match
			return target
		else target = target.next
}
Create one	
return 
}


第一次包含

Target = arrary[index]
while （target is not nil) {
	match? + move to next
}
Create one


Odin里用for来简化：
get_world_chunk :: proc(state: ^GameState, chunkXYZ: V3i, memory: Memory) -> ^WorldChunk {
	h := hashChunk(chunkXYZ)
	head := state.world.chunk_hash[h]
	// 如果通过链表找到符合的chunk，直接返回
	for c := head; c != head; c = c.next_in_hash {
		if c.chunkXYZ == chunkXYZ {
			return c
		}
	}

	// 不然就创建一个新chunk
	new_chunk := new(WorldChunk, memory.perm_alloc)
	new_block := new(WorldEntityBlock, memory.perm_alloc)
	new_chunk^ = WorldChunk{new_block, nil, chunkXYZ}

	state.world.chunk_hash[h] = new_chunk
	return new_chunk
}

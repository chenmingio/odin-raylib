package game

add_demo_terrain :: proc(state: ^GameState, memory: ^Memory) {
	// 先铺一块完整的 level 0 主岛，尺寸略小于初始视口。
	add_tile_grass(
		state.world,
		memory,
		TileArea{V2i{-9, -5}, V2i{18, 10}},
		0,
	)

	// 后写入的高 level 平台直接覆盖主岛上的同坐标 tile。
	add_tile_grass(
		state.world,
		memory,
		TileArea{V2i{-7, 1}, V2i{7, 4}},
		1,
	)
	add_tile_grass(
		state.world,
		memory,
		TileArea{V2i{-6, 3}, V2i{5, 2}},
		2,
	)
	add_tile_grass(
		state.world,
		memory,
		TileArea{V2i{3, 2}, V2i{5, 3}},
		1,
	)

	// 每组楼梯用左右两个 side，并使用低层的 level 作为起点。
	add_stair_grass(state, memory, V2i{-5, 0}, 0, .Left)
	add_stair_grass(state, memory, V2i{-4, 0}, 0, .Right)

	add_stair_grass(state, memory, V2i{-5, 2}, 1, .Left)
	add_stair_grass(state, memory, V2i{-4, 2}, 1, .Right)

	add_stair_grass(state, memory, V2i{4, 1}, 0, .Left)
	add_stair_grass(state, memory, V2i{5, 1}, 0, .Right)
}

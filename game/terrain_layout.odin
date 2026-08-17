package game

add_demo_terrain :: proc(state: ^GameState, memory: ^Memory) {
	// 先铺一块完整的 level 0 主岛，尺寸略小于初始视口。
	add_tile_grass(state.world, memory, TileArea{V2i{-9, -5}, V2i{18, 10}}, 0)

	// 高 level 平台用带立面的 tile 直接覆盖同坐标的 level 0 tile。
	add_tile_grass(state.world, memory, TileArea{V2i{-7, 1}, V2i{7, 4}}, 1)
	add_tile_grass(state.world, memory, TileArea{V2i{-6, 3}, V2i{5, 2}}, 2)
	add_tile_grass(state.world, memory, TileArea{V2i{3, 2}, V2i{5, 3}}, 1)

	// 左侧通道与主岛连续，直接写入普通草地 Center tile。
	left_stair_channel_tiles := [?]V2i {
		{-3, 1},
		{-2, 1},
		{-3, 2},
		{-2, 2},
	}
	for tile_pos in left_stair_channel_tiles {
		set_terrain_tile(
			state.world,
			memory,
			tile_pos,
			TerrainTile{visual = .Flat_Ground_Center, level = 0},
		)
	}

	// 右侧通道位于 level 1 平台内，使用高台地面 Center tile。
	right_stair_channel_tiles := [?]V2i {
		{4, 2},
		{5, 2},
		{4, 3},
		{5, 3},
	}
	for tile_pos in right_stair_channel_tiles {
		set_terrain_tile(
			state.world,
			memory,
			tile_pos,
			TerrainTile{visual = .Elevated_Ground_Center, level = 1},
		)
	}

	// Right side 放在通道左侧，Left side 放在通道右侧。
	add_stair_grass(state, memory, V2i{-4, 1}, 0, .Right)
	add_stair_grass(state, memory, V2i{-2, 1}, 0, .Left)
	add_stair_grass(state, memory, V2i{4, 2}, 0, .Right)
	add_stair_grass(state, memory, V2i{6, 2}, 0, .Left)
}

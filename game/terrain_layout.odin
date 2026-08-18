package game

add_demo_terrain :: proc(state: ^GameState, memory: ^Memory) {
	// 先铺一块完整的 level 0 主岛，尺寸略小于初始视口。
	add_tile_grass(state.world, memory, TileArea{V2i{-9, -5}, V2i{18, 10}}, 0)

	// level 1 顶面会自动上移一格，并在第一排下方补齐立面。
	add_tile_grass(state.world, memory, TileArea{V2i{-7, 1}, V2i{7, 4}}, 1)


	// 左侧通道与主岛连续，直接写入普通草地 Center tile。
	write_terrain_tile(
		state.world,
		memory,
		V2i{-3, 1},
		TerrainTile{visual = .Flat_Ground_Center, level = 0},
	)


	tiles_on_elevate_ground := [?]V2i{{-2, 2}, {-3, 2}, {-4, 2}}
	for tile_pos in tiles_on_elevate_ground {
		write_terrain_tile(
			state.world,
			memory,
			tile_pos,
			TerrainTile{visual = .Elevated_Ground_Narrow_Horizontal_Cliff_Middle, level = 1},
		)
	}

	// Right side 放在通道左侧，Left side 放在通道右侧。
	add_stair_grass(state, memory, V2i{-4, 1}, 0, .Right)
	add_stair_grass(state, memory, V2i{-2, 1}, 0, .Left)
}

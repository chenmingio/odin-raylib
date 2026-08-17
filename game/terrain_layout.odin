package game

TerrainPatch :: struct {
	area:  TileArea,
	level: u8,
}

StairPlacement :: struct {
	tile_pos:  V2i,
	level:     u8,
	direction: StairDirection,
}

add_demo_terrain :: proc(state: ^GameState, memory: ^Memory) {
	// 参考 Tiny Swords 地图的层次：中央主岛、北部高地、东侧村庄和南部离岛。
	patches := [?]TerrainPatch {
		// 中央主战场。
		{area = TileArea{V2i{-7, -2}, V2i{14, 8}}, level = 0},

		// 西北阶梯式高地：下层露台通往城堡平台。
		{area = TileArea{V2i{-14, 1}, V2i{5, 5}}, level = 1},
		{area = TileArea{V2i{-13, 7}, V2i{9, 5}}, level = 2},

		// 北部森林高地。
		{area = TileArea{V2i{2, 8}, V2i{8, 4}}, level = 1},

		// 东侧村庄高地。
		{area = TileArea{V2i{9, -1}, V2i{7, 7}}, level = 1},

		// 南部的三块主要离岛。
		{area = TileArea{V2i{-14, -10}, V2i{7, 6}}, level = 0},
		{area = TileArea{V2i{-4, -12}, V2i{5, 5}}, level = 0},
		{area = TileArea{V2i{4, -10}, V2i{11, 7}}, level = 0},

		// 水面中的小草岛。
		{area = TileArea{V2i{-17, -12}, V2i{2, 1}}, level = 0},
		{area = TileArea{V2i{-7, -14}, V2i{3, 2}}, level = 0},
		{area = TileArea{V2i{0, -7}, V2i{2, 2}}, level = 0},
		{area = TileArea{V2i{16, -8}, V2i{2, 1}}, level = 0},
		{area = TileArea{V2i{12, 8}, V2i{3, 2}}, level = 0},
	}

	for patch in patches {
		add_tile_grass(state.world, memory, patch.area, patch.level)
	}

	// 每组使用左右两块 stair side，形成两格宽的连接口。
	stairs := [?]StairPlacement {
		// 中央主岛 -> 北部森林高地。
		{tile_pos = V2i{3, 6}, level = 0, direction = .Left},
		{tile_pos = V2i{4, 6}, level = 0, direction = .Right},

		// 西北露台 -> 城堡高地。
		{tile_pos = V2i{-12, 5}, level = 1, direction = .Left},
		{tile_pos = V2i{-11, 5}, level = 1, direction = .Right},

		// 东南离岛 -> 村庄高地。
		{tile_pos = V2i{11, -3}, level = 0, direction = .Left},
		{tile_pos = V2i{12, -3}, level = 0, direction = .Right},
	}

	for stair in stairs {
		add_stair_grass(
			state,
			memory,
			stair.tile_pos,
			stair.level,
			stair.direction,
		)
	}
}

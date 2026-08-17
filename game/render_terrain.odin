package game

// pos是相对camera的坐标，需要在函数中转换为buffer坐标
draw_tile :: proc(visual: TileVisual, pos: V3, tilemap: TileMapAsset, buffer: OffScreenBuffer) {
	tile := tile_from_tilemap_asset(tilemap, visual)

	// pos 是 tile 在世界中的左下角；图片绘制接口需要 buffer 中的左上角。
	left_bottom_buffer_pos := rel_pos_to_buffer_pos(pos, buffer)
	left_top_buffer_pos := left_bottom_buffer_pos - V2i{0, tile.frame_size.y}
	draw_image_corp(
		left_top_buffer_pos,
		tile.image,
		buffer,
		source_rect_size = tile.frame_size,
		source_rect_pos = tile.frame_pos,
	)
}

draw_chunk_tile_map :: proc(chunk: ^WorldChunk, state: ^GameState, buffer: OffScreenBuffer) {
	chunk_rel_pos := relative_pos(state.world, WorldPosition{chunk.chunkXYZ, 0}, state.camera_p)
	for row, y in chunk.tile_map {
		for tile, x in row {
			if tile.visual == .Empty {
				continue
			}
			tile_pos := chunk_rel_pos + V3 {
				f32(x) * TILE_SIDE_IN_METERS,
				f32(y) * TILE_SIDE_IN_METERS,
				tile_level_to_z(tile.level),
			}
			draw_tile(tile.visual, tile_pos, state.tilemap1, buffer)
		}
	}
}

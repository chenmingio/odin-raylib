package game

draw_tile :: proc(visual: TileVisual, pos: V2, tilemap: TileMapAsset, buffer: OffScreenBuffer) {
	tile := tile_from_tilemap_asset(tilemap, visual)

	// pos 是 tile 在世界中的左下角；图片绘制接口需要 buffer 中的左上角。
	left_bottom_buffer_pos := rel_pos_to_buffer_pos(V3{pos.x, pos.y, 0}, buffer)
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
		for visual, x in row {
			if visual == .Empty {
				continue
			}
			tile_pos_xy := chunk_rel_pos.xy + V2{f32(x), f32(y)} * TILE_SIDE_IN_METERS
			draw_tile(visual, tile_pos_xy, state.tilemap1, buffer)
		}
	}
}

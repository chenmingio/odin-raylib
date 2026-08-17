package game

import "core:testing"

@(test)
tile_level_to_z_test :: proc(t: ^testing.T) {
	testing.expect_value(t, tile_level_to_z(0), f32(0))
	testing.expect_value(t, tile_level_to_z(2), 2 * TILE_LEVEL_HEIGHT_IN_METERS)
}

@(test)
stair_visual_for_direction_test :: proc(t: ^testing.T) {
	testing.expect_value(t, stair_visual_for_direction(.Left), TileVisual.Stairs_Side_Left)
	testing.expect_value(t, stair_visual_for_direction(.Right), TileVisual.Stairs_Side_Right)
}

package game

import "core:encoding/json"
import "core:fmt"
import "core:image"
import "core:image/png" // 注册 PNG 加载器
import "core:os"

TileArea :: struct {
	min:  V2i,
	size: V2i,
}

StairDirection :: enum u8 {
	Left,
	Right,
}

TileVisual :: enum u16 {
	Empty,
	Flat_Ground_Corner_Top_Left,
	Flat_Ground_Edge_Top,
	Flat_Ground_Corner_Top_Right,
	Flat_Ground_Narrow_Vertical_Top,
	Flat_Ground_Edge_Left,
	Flat_Ground_Center,
	Flat_Ground_Edge_Right,
	Flat_Ground_Narrow_Vertical_Middle,
	Flat_Ground_Corner_Bottom_Left,
	Flat_Ground_Edge_Bottom,
	Flat_Ground_Corner_Bottom_Right,
	Flat_Ground_Narrow_Vertical_Bottom,
	Flat_Ground_Narrow_Horizontal_Left,
	Flat_Ground_Narrow_Horizontal_Middle,
	Flat_Ground_Narrow_Horizontal_Right,
	Flat_Ground_Isolated,
	Stairs_Side_Left,
	Stairs_Side_Right,
	Elevated_Ground_Corner_Top_Left,
	Elevated_Ground_Edge_Top,
	Elevated_Ground_Corner_Top_Right,
	Elevated_Ground_Narrow_Vertical_Top,
	Elevated_Ground_Edge_Left,
	Elevated_Ground_Center,
	Elevated_Ground_Edge_Right,
	Elevated_Ground_Narrow_Vertical_Middle,
	Elevated_Ground_Cliff_Top_Left,
	Elevated_Ground_Cliff_Top,
	Elevated_Ground_Cliff_Top_Right,
	Elevated_Ground_Narrow_Vertical_Cliff_Top,
	Elevated_Ground_Cliff_Face_Left,
	Elevated_Ground_Cliff_Face,
	Elevated_Ground_Cliff_Face_Right,
	Elevated_Ground_Narrow_Vertical_Cliff_Face,
	Elevated_Ground_Narrow_Horizontal_Left,
	Elevated_Ground_Narrow_Horizontal_Middle,
	Elevated_Ground_Narrow_Horizontal_Right,
	Elevated_Ground_Isolated,
	Elevated_Ground_Narrow_Horizontal_Cliff_Left,
	Elevated_Ground_Narrow_Horizontal_Cliff_Middle,
	Elevated_Ground_Narrow_Horizontal_Cliff_Right,
	Elevated_Ground_Isolated_Cliff,
}

TileMapRect :: struct {
	x, y, w, h: i32,
}

TileMapSliceKey :: struct {
	frame:  i32,
	bounds: TileMapRect,
}

TileMapSlice :: struct {
	name: TileVisual,
	keys: []TileMapSliceKey,
}

TileMapSheet :: struct {
	meta: struct {
		size:   struct {
			w, h: i32,
		},
		slices: []TileMapSlice,
	},
}

Tile :: struct {
	image:      ^image.Image,
	frame_size: V2i,
	frame_pos:  V2i,
}

TerrainTile :: struct {
	visual: TileVisual,
	level:  u8,
}

TileMapAsset :: struct {
	image: ^image.Image,
	tiles: [TileVisual]Tile,
}

load_tilemap_asset :: proc(
	game_memory: ^Memory,
	image_path: string,
	json_path: string,
) -> TileMapAsset {
	img, img_err := image.load_from_file(image_path, {}, game_memory.perm_alloc)
	assert(img_err == nil, fmt.tprintf("failed to load tilemap image: %s", image_path))

	json_data, json_err := os.read_entire_file(json_path, game_memory.temp_alloc)
	assert(json_err == nil, fmt.tprintf("failed to load tilemap metadata: %s", json_path))

	sheet := TileMapSheet{}
	parse_err := json.unmarshal(json_data, &sheet, allocator = game_memory.temp_alloc)
	assert(parse_err == nil, fmt.tprintf("failed to parse tilemap metadata: %s", json_path))

	asset := TileMapAsset {
		image = img,
	}
	loaded: [TileVisual]bool

	assert(sheet.meta.size.w == i32(img.width) && sheet.meta.size.h == i32(img.height))
	for slice in sheet.meta.slices {
		visual := slice.name
		assert(visual != .Empty, "invalid TileVisual name in tilemap metadata")
		assert(!loaded[visual], fmt.tprintf("duplicate TileVisual: %v", visual))
		assert(len(slice.keys) > 0, fmt.tprintf("tile has no bounds: %v", visual))
		bounds := slice.keys[0].bounds
		assert(
			bounds.x >= 0 &&
			bounds.y >= 0 &&
			bounds.w > 0 &&
			bounds.h > 0 &&
			bounds.x + bounds.w <= i32(img.width) &&
			bounds.y + bounds.h <= i32(img.height),
			fmt.tprintf("tile is outside the atlas: %v", visual),
		)

		asset.tiles[visual] = Tile {
			image      = img,
			frame_size = V2i{bounds.w, bounds.h},
			frame_pos  = V2i{bounds.x, bounds.y},
		}
		loaded[visual] = true
	}

	for visual in TileVisual {
		if visual == .Empty {continue}
		assert(loaded[visual], fmt.tprintf("TileVisual missing from tilemap metadata: %v", visual))
	}

	return asset
}

tile_from_tilemap_asset :: proc(asset: TileMapAsset, visual: TileVisual) -> Tile {
	assert(visual != .Empty)
	tile := asset.tiles[visual]
	assert(tile.image != nil, fmt.tprintf("TileVisual not loaded: %v", visual))
	return tile
}

stair_visual_for_direction :: proc(direction: StairDirection) -> TileVisual {
	if direction == .Left {
		return .Stairs_Side_Left
	}
	return .Stairs_Side_Right
}

flat_ground_visual_for_tile :: proc(area: TileArea, tile_pos: V2i) -> TileVisual {
	assert(area.size.x > 0 && area.size.y > 0)
	max_pos := area.min + area.size - 1
	assert(
		tile_pos.x >= area.min.x &&
		tile_pos.x <= max_pos.x &&
		tile_pos.y >= area.min.y &&
		tile_pos.y <= max_pos.y,
	)

	is_left := tile_pos.x == area.min.x
	is_right := tile_pos.x == max_pos.x
	is_bottom := tile_pos.y == area.min.y
	is_top := tile_pos.y == max_pos.y

	if area.size.x == 1 && area.size.y == 1 {
		return .Flat_Ground_Isolated
	}
	if area.size.x == 1 {
		if is_top {return .Flat_Ground_Narrow_Vertical_Top}
		if is_bottom {return .Flat_Ground_Narrow_Vertical_Bottom}
		return .Flat_Ground_Narrow_Vertical_Middle
	}
	if area.size.y == 1 {
		if is_left {return .Flat_Ground_Narrow_Horizontal_Left}
		if is_right {return .Flat_Ground_Narrow_Horizontal_Right}
		return .Flat_Ground_Narrow_Horizontal_Middle
	}

	if is_top {
		if is_left {return .Flat_Ground_Corner_Top_Left}
		if is_right {return .Flat_Ground_Corner_Top_Right}
		return .Flat_Ground_Edge_Top
	}
	if is_bottom {
		if is_left {return .Flat_Ground_Corner_Bottom_Left}
		if is_right {return .Flat_Ground_Corner_Bottom_Right}
		return .Flat_Ground_Edge_Bottom
	}
	if is_left {return .Flat_Ground_Edge_Left}
	if is_right {return .Flat_Ground_Edge_Right}
	return .Flat_Ground_Center
}

tile_level_y_offset :: proc(level: u8) -> i32 {
	return i32(level)
}

elevated_ground_surface_visual_for_tile :: proc(area: TileArea, tile_pos: V2i) -> TileVisual {
	assert(area.size.x > 0 && area.size.y > 0)
	max_pos := area.min + area.size - 1
	assert(
		tile_pos.x >= area.min.x &&
		tile_pos.x <= max_pos.x &&
		tile_pos.y >= area.min.y &&
		tile_pos.y <= max_pos.y,
	)

	is_left := tile_pos.x == area.min.x
	is_right := tile_pos.x == max_pos.x
	is_bottom := tile_pos.y == area.min.y
	is_top := tile_pos.y == max_pos.y

	if area.size.x == 1 {
		if area.size.y == 1 {return .Elevated_Ground_Isolated}
		if is_top {return .Elevated_Ground_Narrow_Vertical_Top}
		if is_bottom {return .Elevated_Ground_Narrow_Vertical_Cliff_Top}
		return .Elevated_Ground_Narrow_Vertical_Middle
	}

	if area.size.y == 1 {
		if is_left {return .Elevated_Ground_Narrow_Horizontal_Left}
		if is_right {return .Elevated_Ground_Narrow_Horizontal_Right}
		return .Elevated_Ground_Narrow_Horizontal_Middle
	}

	if is_top {
		if is_left {return .Elevated_Ground_Corner_Top_Left}
		if is_right {return .Elevated_Ground_Corner_Top_Right}
		return .Elevated_Ground_Edge_Top
	}
	if is_bottom {
		if is_left {return .Elevated_Ground_Cliff_Top_Left}
		if is_right {return .Elevated_Ground_Cliff_Top_Right}
		return .Elevated_Ground_Cliff_Top
	}
	if is_left {return .Elevated_Ground_Edge_Left}
	if is_right {return .Elevated_Ground_Edge_Right}
	return .Elevated_Ground_Center
}

elevated_ground_cliff_face_visual_for_x :: proc(area: TileArea, x: i32) -> TileVisual {
	assert(area.size.x > 0 && area.size.y > 0)
	max_x := area.min.x + area.size.x - 1
	assert(x >= area.min.x && x <= max_x)

	is_left := x == area.min.x
	is_right := x == max_x

	if area.size.x == 1 {
		if area.size.y == 1 {return .Elevated_Ground_Isolated_Cliff}
		return .Elevated_Ground_Narrow_Vertical_Cliff_Face
	}
	if area.size.y == 1 {
		if is_left {return .Elevated_Ground_Narrow_Horizontal_Cliff_Left}
		if is_right {return .Elevated_Ground_Narrow_Horizontal_Cliff_Right}
		return .Elevated_Ground_Narrow_Horizontal_Cliff_Middle
	}
	if is_left {return .Elevated_Ground_Cliff_Face_Left}
	if is_right {return .Elevated_Ground_Cliff_Face_Right}
	return .Elevated_Ground_Cliff_Face
}

grass_surface_visual_for_tile :: proc(area: TileArea, tile_pos: V2i, level: u8) -> TileVisual {
	if level == 0 {
		return flat_ground_visual_for_tile(area, tile_pos)
	}
	return elevated_ground_surface_visual_for_tile(area, tile_pos)
}

write_terrain_tile :: proc(
	world: ^World,
	memory: ^Memory,
	tile_pos: V2i,
	tile: TerrainTile,
) {
	chunk_x, local_x := tile_axis_to_chunk(tile_pos.x, CHUNK_TILE_DIM.x)
	chunk_y, local_y := tile_axis_to_chunk(tile_pos.y, CHUNK_TILE_DIM.y)
	chunk := get_world_chunk(world, V3i{chunk_x, chunk_y, 0}, memory)
	chunk.tile_map[local_y][local_x] = tile
}

add_tile_grass :: proc(world: ^World, memory: ^Memory, area: TileArea, level: u8) {
	assert(area.size.x > 0 && area.size.y > 0)
	y_offset := tile_level_y_offset(level)

	for y in area.min.y ..< area.min.y + area.size.y {
		for x in area.min.x ..< area.min.x + area.size.x {
			logical_pos := V2i{x, y}
			surface_pos := V2i{x, y + y_offset}
			write_terrain_tile(
				world,
				memory,
				surface_pos,
				TerrainTile {
					visual = grass_surface_visual_for_tile(area, logical_pos, level),
					level  = level,
				},
			)
		}
	}

	if level > 0 {
		for face_y in area.min.y ..< area.min.y + y_offset {
			for x in area.min.x ..< area.min.x + area.size.x {
				write_terrain_tile(
					world,
					memory,
					V2i{x, face_y},
					TerrainTile {
						visual = elevated_ground_cliff_face_visual_for_x(area, x),
						level  = level,
					},
				)
			}
		}
	}
}

set_terrain_tile :: proc(
	world: ^World,
	memory: ^Memory,
	tile_pos: V2i,
	level: u8,
) {
	add_tile_grass(world, memory, TileArea{tile_pos, V2i{1, 1}}, level)
}

add_stair_grass :: proc(
	state: ^GameState,
	memory: ^Memory,
	tile_pos: V2i,
	level: u8,
	direction: StairDirection,
) {
	chunk_x, local_x := tile_axis_to_chunk(tile_pos.x, CHUNK_TILE_DIM.x)
	chunk_y, local_y := tile_axis_to_chunk(tile_pos.y, CHUNK_TILE_DIM.y)

	add_low_entity(
		state,
		LowEntity {
			pos = world_pos(
				state.world,
				V3i{chunk_x, chunk_y, 0},
				V3 {
					f32(local_x) * TILE_SIDE_IN_METERS,
					f32(local_y) * TILE_SIDE_IN_METERS,
					0,
				},
			),
			type            = .Stair,
			moveable        = false,
			stair_direction = direction,
			stair_level     = level,
		},
		memory,
	)
}

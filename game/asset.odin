package game

import "core:encoding/json" // 必须保留！用于注册 PNG 加载器
import "core:fmt"
import "core:image"
import "core:image/png"
import "core:os"


load_aseprite_assets :: proc(
	game_memory: ^Memory,
	game_state: ^GameState,
	file_path: string,
	json_path: string,
) -> AseSpriteAsset {
	img, img_err := image.load_from_file(file_path, {}, game_memory.temp_alloc)
	assert(img_err == nil)

	json_data, json_err := os.read_entire_file(json_path, game_memory.temp_alloc)
	assert(json_err == nil)

	assets := AseSpriteAsset{}
	parse_err := json.unmarshal(json_data, &assets.sheet)
	assets.image = img
	assert(parse_err == nil)

	return assets
}

TileMapSliceKey :: struct {
	frame:  i32,
	bounds: AseRect,
}

TileMapSlice :: struct {
	name: string,
	keys: []TileMapSliceKey,
}

TileMapSheet :: struct {
	meta: struct {
		size: struct {
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

TileMapAsset :: struct {
	image: ^image.Image,
	tiles: map[string]Tile,
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
	parse_err := json.unmarshal(json_data, &sheet, allocator = game_memory.perm_alloc)
	assert(parse_err == nil, fmt.tprintf("failed to parse tilemap metadata: %s", json_path))

	asset := TileMapAsset {
		image = img,
		tiles = make(map[string]Tile, len(sheet.meta.slices), game_memory.perm_alloc),
	}

	assert(sheet.meta.size.w == i32(img.width) && sheet.meta.size.h == i32(img.height))
	for slice in sheet.meta.slices {
		assert(len(slice.keys) > 0, fmt.tprintf("tile has no bounds: %s", slice.name))
		bounds := slice.keys[0].bounds
		assert(
			bounds.x >= 0 && bounds.y >= 0 &&
			bounds.w > 0 && bounds.h > 0 &&
			bounds.x + bounds.w <= i32(img.width) &&
			bounds.y + bounds.h <= i32(img.height),
			fmt.tprintf("tile is outside the atlas: %s", slice.name),
		)

		_, exists := asset.tiles[slice.name]
		assert(!exists, fmt.tprintf("duplicate tile name: %s", slice.name))
		asset.tiles[slice.name] = Tile {
			image      = img,
			frame_size = V2i{bounds.w, bounds.h},
			frame_pos  = V2i{bounds.x, bounds.y},
		}
	}

	return asset
}

tile_from_tilemap_asset :: proc(asset: TileMapAsset, name: string) -> Tile {
	tile, ok := asset.tiles[name]
	assert(ok, fmt.tprintf("tile not found: %s", name))
	return tile
}

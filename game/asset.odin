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

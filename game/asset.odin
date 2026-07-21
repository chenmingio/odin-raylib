package game

import "core:encoding/json" // 必须保留！用于注册 PNG 加载器
import "core:fmt"
import "core:image"
import "core:image/png"
import "core:os"


load_animate_assets :: proc(
	game_memory: ^Memory,
	game_state: ^GameState,
	file_path: string,
	json_path: string,
	prefix: string,
	pivot_in_source: V2i,
) -> Animation {
	// 载入单位动画
	img, img_err := image.load_from_file(file_path, {}, game_memory.temp_alloc)
	assert(img_err == nil)

	json_data, json_err := os.read_entire_file(json_path, game_memory.temp_alloc)
	assert(json_err == nil)

	animate := AseSpriteSheet{}
	parse_err := json.unmarshal(json_data, &animate)
	assert(parse_err == nil)

	return animation_from_ase_sprite_sheet(animate, img, pivot_in_source, prefix)
}

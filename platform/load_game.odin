package platform

import "../game"
import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:time"

GAME_DLL_PATH :: "build/game-lib.dylib"


// stub functions is default implementation which does nothing
game_update_and_render_stub: game.UpdateAndRenderProc = proc(
	_: ^game.Memory,
	_: game.Input,
	_: game.OffScreenBuffer,
	_: f32,
) {}


game_get_sound_samples_stub: game.GetSoundSamplesProc = proc(
	game_memory: ^game.Memory,
	sound_buffer: ^game.SoundOutputBuffer,
) {}

RayLibGameCode :: struct {
	game_update_and_render: game.UpdateAndRenderProc,
	game_get_sound_samples: game.GetSoundSamplesProc,
	game_code_dll:          dynlib.Library,
	last_write_time:        time.Time,
	is_valid:               bool,
}


// load game code from dynamic library
// if game code is not valid, use stub functions
// 
load_game_code :: proc() -> RayLibGameCode {
	result := RayLibGameCode{}

	result.game_update_and_render = game_update_and_render_stub
	result.game_get_sound_samples = game_get_sound_samples_stub

	lib, ok := dynlib.load_library(GAME_DLL_PATH)
	if !ok {
		fmt.eprintln(">>> Error loading game lib:", dynlib.last_error())
		return result
	}

	result.game_code_dll = lib

	update_proc_ptr, found_update := dynlib.symbol_address(lib, "update_and_render")
	sound_proc_ptr, found_sound := dynlib.symbol_address(lib, "get_sound_samples")

	if found_update && found_sound {
		result.game_update_and_render = cast(game.UpdateAndRenderProc)update_proc_ptr
		result.game_get_sound_samples = cast(game.GetSoundSamplesProc)sound_proc_ptr
		result.is_valid = true

		file_info, err := os.stat(GAME_DLL_PATH)
		if err == os.ERROR_NONE {
			result.last_write_time = file_info.modification_time
		} else {
			fmt.eprintln(">>> Error getting game lib file info:", err)
		}
	} else {
		fmt.eprintln(">>> Game lib is not valid")
	}

	if !result.is_valid {
		unload_game_code(&result)
	}

	return result
}

unload_game_code :: proc(code: ^RayLibGameCode) {
	if code^.game_code_dll != nil {
		dynlib.unload_library(code^.game_code_dll)
		code^.game_code_dll = nil
	}
	code^.is_valid = false
	code^.game_update_and_render = game_update_and_render_stub
	code^.game_get_sound_samples = game_get_sound_samples_stub
}

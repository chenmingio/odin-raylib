package main

import "core:dynlib"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:slice"
import "core:time"
import "game"
import "platform"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 600
TARGET_FRAME_RATE :: 60


main :: proc() {
	monitorRefreshRate := rl.GetMonitorRefreshRate(rl.GetCurrentMonitor())
	fmt.println(">>> Monitor refresh rate: ", monitorRefreshRate)

	targetFPS := min(monitorRefreshRate, TARGET_FRAME_RATE)
	rl.SetTargetFPS(targetFPS)
	fmt.println(">>> Target FPS set to: ", targetFPS)
	rl.SetTraceLogLevel(rl.TraceLogLevel.TRACE)

	flags :: rl.ConfigFlags{rl.ConfigFlag.VSYNC_HINT, rl.ConfigFlag.WINDOW_HIGHDPI}
	rl.SetConfigFlags(flags)

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Hello World!")

	// load game controller config
	fileText := rl.LoadFileText("resources/gamecontrollerdb.txt")
	if fileText != nil {
		rl.SetGamepadMappings(cstring(fileText))
	}

	off_screen_image := rl.GenImageColor(SCREEN_WIDTH, SCREEN_HEIGHT, rl.BLANK)
	game_off_screen := game.OffScreenBuffer {
		// cast is before from_ptr
		slice.from_ptr(cast(^u32)off_screen_image.data, SCREEN_WIDTH * SCREEN_HEIGHT),
		u32(off_screen_image.width),
		u32(off_screen_image.height),
	}
	bufferTexture := rl.LoadTextureFromImage(off_screen_image)

	game_input := game.Input{}
	keyboard_controller := &game_input.controllers[0]
	keyboard_controller.isConnected = true

	is_paused := false
	game_code := platform.load_game_code()

	game_memory := game.Memory{}
	storage_size := 64 * mem.Megabyte
	arena_backing := make([]byte, storage_size)
	arena := mem.Arena{}
	mem.arena_init(&arena, arena_backing)
	arena_allocator := mem.arena_allocator(&arena)
	context.allocator = arena_allocator

	game_memory.arena = arena

	// game loop
	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.GREEN)

		// input

		keyboard_controller^.move_up.ended_down = rl.IsKeyDown(rl.KeyboardKey.W)
		keyboard_controller^.move_down.ended_down = rl.IsKeyDown(rl.KeyboardKey.S)
		keyboard_controller^.move_left.ended_down = rl.IsKeyDown(rl.KeyboardKey.A)
		keyboard_controller^.move_right.ended_down = rl.IsKeyDown(rl.KeyboardKey.D)

		// recording

		// dynamic game loading
		file_info, err := os.stat(platform.GAME_DLL_PATH)
		if err == os.ERROR_NONE {
			current_write_time := file_info.modification_time
			if time.diff(game_code.last_write_time, current_write_time) > 0 {
				fmt.println(">>> Game code has changed, reloading...")
				platform.unload_game_code(&game_code)
				game_code = platform.load_game_code()
				game_code.last_write_time = current_write_time
			}
		}

		// TODO sound

		// pause 
		if rl.IsKeyPressed(rl.KeyboardKey.P) {
			is_paused = !is_paused
		}

		time_span := rl.GetFrameTime()
		// update and render
		if !is_paused {
			game_code.game_update_and_render(&game_memory, game_input, game_off_screen, time_span)
			rl.UpdateTexture(bufferTexture, off_screen_image.data)
			rl.DrawTexture(bufferTexture, 0, 0, rl.WHITE)
		} else {
			rl.DrawText("PAUSED", SCREEN_WIDTH / 2 - 40, SCREEN_HEIGHT / 2 - 20, 40, rl.WHITE)
		}
		rl.EndDrawing()
	}
	rl.UnloadTexture(bufferTexture)
	rl.CloseWindow()
}

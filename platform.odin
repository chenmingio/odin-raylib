package platform

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

import "game"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 600
TARGET_FRAME_RATE :: 60

main :: proc() {
	monitorRefreshRate := rl.GetMonitorRefreshRate(rl.GetCurrentMonitor())
	fmt.println("Monitor refresh rate: ", monitorRefreshRate)

	targetFPS := min(monitorRefreshRate, TARGET_FRAME_RATE)
	rl.SetTargetFPS(targetFPS)
	fmt.println("Target FPS set to: ", targetFPS)
	rl.SetTraceLogLevel(rl.TraceLogLevel.TRACE)

	flags := rl.ConfigFlags{rl.ConfigFlag.VSYNC_HINT, rl.ConfigFlag.WINDOW_HIGHDPI}
	rl.SetConfigFlags(flags)

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Hello World!")

	// SearchAndSetResourceDir("resources");
	// load game controller config
	fileText := rl.LoadFileText("gamecontrollerdb.txt")
	if fileText != nil {
		rl.SetGamepadMappings(cstring(fileText))
	}

	off_screen_image := rl.GenImageColor(SCREEN_WIDTH, SCREEN_HEIGHT, rl.BLANK)
	game_off_screen := game.GameOffScreenBuffer {
		off_screen_image.data,
		(u32)(off_screen_image.width),
		(u32)(off_screen_image.height),
		(u32)(off_screen_image.width),
	}

	input := game.GameInput{}
	keyboard_controller := &input.controllers[0]
	keyboard_controller.isConnected = true

	is_paused := false

	// game loop
	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(rl.KeyboardKey.P) {
			is_paused = !is_paused
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		keyboard_controller^.move_up.ended_down = rl.IsKeyDown(rl.KeyboardKey.W)
		keyboard_controller^.move_down.ended_down = rl.IsKeyDown(rl.KeyboardKey.S)
		keyboard_controller^.move_left.ended_down = rl.IsKeyDown(rl.KeyboardKey.A)
		keyboard_controller^.move_right.ended_down = rl.IsKeyDown(rl.KeyboardKey.D)

		if !is_paused {
			game.game_update_and_render(input)
		} else {
			rl.DrawText("PAUSED", SCREEN_WIDTH / 2 - 40, SCREEN_HEIGHT / 2 - 20, 40, rl.WHITE)
		}

		rl.EndDrawing()
	}
	rl.CloseWindow()
}

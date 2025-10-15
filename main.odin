package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:slice"
import "core:time"
import "game"
import "platform"
import rl "vendor:raylib"


// 平台能力
// 动态加载游戏库
// Arena内存分配器
// 屏幕buffer
// 输入
// TODO
// 音频
// recording & replay

// 简化类型名
Sample :: platform.Sample


main :: proc() {
	// 没有正确打包应用，目前无法获取显示器信息
	// screen_width := rl.GetMonitorWidth(rl.GetCurrentMonitor())
	// screen_height := rl.GetMonitorHeight(rl.GetCurrentMonitor())
	// name := rl.GetMonitorName(rl.GetCurrentMonitor())
	// monitorRefreshRate := rl.GetMonitorRefreshRate(rl.GetCurrentMonitor())

	screen_width := i32(5120 / 2)
	screen_height := i32(2880 / 2)
	target_fps := i32(60)

	rl.SetTargetFPS(target_fps)
	rl.SetTraceLogLevel(rl.TraceLogLevel.TRACE)

	flags :: rl.ConfigFlags {
		rl.ConfigFlag.VSYNC_HINT,
		rl.ConfigFlag.WINDOW_HIGHDPI,
		// rl.ConfigFlag.FULLSCREEN_MODE,
	}
	rl.SetConfigFlags(flags)

	rl.InitWindow(screen_width, screen_height, "Hello World!")

	stream := platform.init_audio()

	// load game controller config
	fileText := rl.LoadFileText("resources/gamecontrollerdb.txt")
	if fileText != nil {
		rl.SetGamepadMappings(cstring(fileText))
	}

	// 显示
	off_screen_image := rl.GenImageColor(screen_width, screen_height, rl.BLANK)
	game_off_screen := game.OffScreenBuffer {
		// cast is before from_ptr
		slice.from_ptr(cast(^u32)off_screen_image.data, int(screen_width * screen_height)),
		off_screen_image.width,
		off_screen_image.height,
	}
	bufferTexture := rl.LoadTextureFromImage(off_screen_image)

	// 控制
	game_input := game.Input{}
	keyboard_controller := &game_input.controllers[0]
	keyboard_controller.isConnected = true

	is_paused := false

	game_code := platform.load_game_code()

	// 内存管理
	game_memory := game.Memory{}

	permanent_storage_size := 64 * mem.Megabyte
	temporary_storage_size := 1 * mem.Gigabyte

	// Arena内存分配器
	// 先在heap上分配好空间(使用默认分配器)
	permanent_storage := make([]byte, permanent_storage_size)
	temporary_storage := make([]byte, temporary_storage_size)
	assert(permanent_storage != nil)
	assert(temporary_storage != nil)

	// 构建arena分配器
	permanent_arena := mem.Arena{}
	mem.arena_init(&permanent_arena, permanent_storage)
	permanent_arena_allocator := mem.arena_allocator(&permanent_arena)
	context.allocator = permanent_arena_allocator // 修改默认分配器为Arena分配器

	temporary_arena := mem.Arena{}
	mem.arena_init(&temporary_arena, temporary_storage)
	temporary_arena_allocator := mem.arena_allocator(&temporary_arena)
	context.temp_allocator = temporary_arena_allocator // 临时分配器也用Arena分配器(不同的储存空间)

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

		// 查看游戏库，如果修改时间晚于上次的记录时间，就重新加载
		file_info, err := os.stat(platform.GAME_DLL_PATH)
		if err == os.ERROR_NONE {
			current_write_time := file_info.modification_time
			if time.diff(game_code.last_write_time, current_write_time) > 0 {
				fmt.println("游戏代码已更新，重新加载...")
				platform.unload_game_code(&game_code)
				game_code = platform.load_game_code()
				game_code.last_write_time = current_write_time
			}
		}
		// pause
		if rl.IsKeyPressed(rl.KeyboardKey.P) {
			is_paused = !is_paused
		}

		// 更新音频
		platform.update_audio(is_paused)

		time_span := rl.GetFrameTime()
		// update and render
		if !is_paused {
			game_code.game_update_and_render(&game_memory, game_input, game_off_screen, time_span)
			rl.UpdateTexture(bufferTexture, off_screen_image.data)
			rl.DrawTexture(bufferTexture, 0, 0, rl.WHITE)
		} else {
			rl.DrawText("PAUSED", screen_width / 2 - 40, screen_height / 2 - 20, 40, rl.WHITE)
		}

		rl.EndDrawing()
	}
	rl.UnloadTexture(bufferTexture)
	rl.CloseWindow()
}

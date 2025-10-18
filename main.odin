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
// 屏幕buffer
// 动态加载游戏库
// Arena内存分配器
// 输入
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
	// 分配游戏内存 - 使用连续内存块（匹配 C 版本）
	permanent_storage_size := mem.Megabyte * 256 // 256MB 永久内存
	temporary_storage_size := mem.Megabyte * 64 // 64MB 临时内存
	total_storage_size := permanent_storage_size + temporary_storage_size

	// 分配一块连续内存，然后分割成两部分
	total_storage := make([]byte, total_storage_size)
	permanent_storage := total_storage[:permanent_storage_size]
	game_memory.permanent_storage = permanent_storage
	temporary_storage := total_storage[permanent_storage_size:]
	assert(permanent_storage != nil)
	assert(temporary_storage != nil)

	// 构建arena分配器. Arena的构造器需要传入arena结构体和data slice，方便你直接操作data区域
	permanent_arena := mem.Arena{} // 这里储存着Arena结构体，包括元数据
	mem.arena_init(&permanent_arena, permanent_storage) // 第二个参数就是data slice
	permanent_arena_allocator := mem.arena_allocator(&permanent_arena)
	context.allocator = permanent_arena_allocator // 修改默认分配器为Arena分配器

	temporary_arena := mem.Arena{}
	mem.arena_init(&temporary_arena, temporary_storage)
	temporary_arena_allocator := mem.arena_allocator(&temporary_arena)
	context.temp_allocator = temporary_arena_allocator // 临时分配器也用Arena分配器(不同的储存空间)

	// 录制回放状态
	// 记录内存的起始点和总大小（使用连续内存块）
	record_state := platform.RayLibState {
		game_memory_block = raw_data(total_storage), // 指向连续内存的开头
		total_size        = total_storage_size,
	}

	// game loop
	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.GREEN)

		// input

		// 录制回放控制 (使用 L 键，匹配 C 版本逻辑)
		if rl.IsKeyPressed(rl.KeyboardKey.L) {
			if record_state.is_recording {
				// 正在录制 → 停止录制并开始回放
				platform.stop_recording(&record_state)
				platform.start_replaying(&record_state, "input_recording.dat")
			} else if record_state.is_replaying {
				// 正在回放 → 停止回放
				platform.stop_replaying(&record_state)
			} else {
				// 都没有 → 开始录制
				platform.start_recording(&record_state, "input_recording.dat")
			}
		}

		// 根据当前模式获取输入
		if record_state.is_replaying {
			// 回放模式：从文件读取输入
			platform.loop_read_input(&record_state, &game_input)
		} else {
			// 正常模式：获取真实输入
			keyboard_controller^.move_up.ended_down = rl.IsKeyDown(rl.KeyboardKey.W)
			keyboard_controller^.move_down.ended_down = rl.IsKeyDown(rl.KeyboardKey.S)
			keyboard_controller^.move_left.ended_down = rl.IsKeyDown(rl.KeyboardKey.A)
			keyboard_controller^.move_right.ended_down = rl.IsKeyDown(rl.KeyboardKey.D)

			// 录制模式：保存输入到文件
			if record_state.is_recording {
				platform.record_input(&record_state, &game_input)
			}
		}

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

		// 显示录制回放状态
		status_y := i32(10)
		if record_state.is_recording {
			rl.DrawText("RECORDING (L to stop & replay)", 10, status_y, 20, rl.RED)
			status_y += 25
		}
		if record_state.is_replaying {
			rl.DrawText("REPLAYING (L to stop)", 10, status_y, 20, rl.BLUE)
			status_y += 25
		}
		if !record_state.is_recording && !record_state.is_replaying {
			rl.DrawText("L: Record/Replay | P: Pause", 10, status_y, 20, rl.WHITE)
		}

		rl.EndDrawing()
	}

	rl.UnloadTexture(bufferTexture)
	rl.CloseWindow()
}

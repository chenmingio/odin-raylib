package main

import "base:runtime"
import "core:fmt"
import "core:math"
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

TARGET_FRAME_RATE :: 60 // 目标帧率
SAMPLE_RATE :: 48000 // 48kHz 采样率
CHANNELS :: 2 // 双声道
BITS_PER_SAMPLE :: 16 // 16位深度 (i16) 单个声道的位深度(sample类型就是i16)
BYTES_PER_SAMPLE :: BITS_PER_SAMPLE / 8 // 单个样本的字节数 = 2
BYTES_PER_FRAME :: BYTES_PER_SAMPLE * CHANNELS // 一帧的字节数 = 4

// 简化类型名
Sample :: platform.Sample

MAX_SAMPLES_PER_UPDATE :: SAMPLE_RATE / TARGET_FRAME_RATE // raylib的callback每次更新的样本数
MAX_SAMPLES_SECONDS :: 3 // 最大储存3秒的内容

// 全局环形缓冲区
ring_output: platform.RayLibSoundOutput

// 全局音频生成状态
audio_time: f32 = 0.0 // 累计时间，用于生成连续声波

// 环形缓冲区读取
ring_buffer_consume :: proc(buffer: []Sample, read_index: ^int, output: []Sample) {
	samples_to_read := len(output)
	buffer_size := len(buffer)
	current_read := read_index^

	// 计算 region1 和 region2 的大小
	region1_size, region2_size: int

	if current_read + samples_to_read > buffer_size {
		region1_size = buffer_size - current_read
		region2_size = samples_to_read - region1_size
	} else {
		region1_size = samples_to_read
	}

	// 复制 region1
	copy(output, buffer[current_read:][:region1_size])

	// 复制 region2 (如果需要)
	if region2_size > 0 {
		copy(output[region1_size:], buffer[:region2_size])
		read_index^ = region2_size
	} else {
		// 没有回绕，直接更新索引
		read_index^ = current_read + region1_size
	}
}

// 直接写入音频到环形缓冲区 - 边计算边写入，无需中间缓冲区
ring_buffer_produce :: proc(
	buffer: []Sample,
	write_index: ^int,
	sample_count: int,
	frequency: f32 = 440.0,
) {
	buffer_size := len(buffer)
	current_write := write_index^
	dt := 1.0 / f32(SAMPLE_RATE) // 时间步长

	// 计算 region1 和 region2 的大小
	region1_size, region2_size: int

	if current_write + sample_count > buffer_size {
		region1_size = buffer_size - current_write
		region2_size = sample_count - region1_size
	} else {
		region1_size = sample_count
	}

	// 写入 region1 - 直接计算并写入
	for i in 0 ..< region1_size / 2 {
		sine_value := math.sin(2 * math.PI * frequency * audio_time)
		sample := Sample(sine_value * 8000.0)

		buffer[current_write + i * 2] = sample // 左声道
		buffer[current_write + i * 2 + 1] = sample // 右声道

		audio_time += dt
	}

	// 写入 region2 (如果需要)
	if region2_size > 0 {
		for i in 0 ..< region2_size / 2 {
			sine_value := math.sin(2 * math.PI * frequency * audio_time)
			sample := Sample(sine_value * 8000.0)

			buffer[i * 2] = sample // 左声道
			buffer[i * 2 + 1] = sample // 右声道

			audio_time += dt
		}
		write_index^ = region2_size
	} else {
		// 没有回绕，直接更新索引
		write_index^ = current_write + region1_size
	}
}


// 音频回调 - 从环形缓冲区读取数据
audio_input_callback :: proc "c" (bufferData: rawptr, frames: u32) {
	// 这是c函数的回调函数，但是使用了slice.from_ptr这个odin函数，所以需要context。
	// context包括了odin的运行时信息，比如内存分配器/assert函数等。
	// context是odin运行时的上下文（reserved变量名），所以这里是覆盖不是新建context
	context = runtime.default_context()

	// 将 rawptr 转换为 Sample slice
	output_samples := slice.from_ptr(cast(^Sample)bufferData, int(frames * CHANNELS))

	// 从环形缓冲区读取音频数据
	if len(ring_output.samples) > 0 {
		ring_buffer_consume(ring_output.samples, &ring_output.read_index, output_samples)
	} else {
		// 如果没有数据，输出静音
		for i in 0 ..< len(output_samples) {
			output_samples[i] = 0
		}
	}
}

setup_audio :: proc() -> rl.AudioStream {
	rl.InitAudioDevice()
	rl.SetAudioStreamBufferSizeDefault(MAX_SAMPLES_PER_UPDATE)
	stream := rl.LoadAudioStream(SAMPLE_RATE, BITS_PER_SAMPLE, CHANNELS)
	rl.SetAudioStreamCallback(stream, audio_input_callback)
	rl.PlayAudioStream(stream) // 只在初始化时调用一次
	return stream
}

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

	// 初始化环形音频缓冲区 - 3秒的音频数据
	buffer_size := SAMPLE_RATE * CHANNELS * MAX_SAMPLES_SECONDS
	ring_output = platform.RayLibSoundOutput {
		samples     = make([]Sample, buffer_size),
		read_index  = 0,
		write_index = 0,
		sample_rate = SAMPLE_RATE,
		duration    = MAX_SAMPLES_SECONDS,
	}

	stream := setup_audio()

	// load game controller config
	fileText := rl.LoadFileText("resources/gamecontrollerdb.txt")
	if fileText != nil {
		rl.SetGamepadMappings(cstring(fileText))
	}

	off_screen_image := rl.GenImageColor(screen_width, screen_height, rl.BLANK)
	game_off_screen := game.OffScreenBuffer {
		// cast is before from_ptr
		slice.from_ptr(cast(^u32)off_screen_image.data, int(screen_width * screen_height)),
		off_screen_image.width,
		off_screen_image.height,
	}
	bufferTexture := rl.LoadTextureFromImage(off_screen_image)

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

		// 直接生成音频数据到环形缓冲区
		if !is_paused {
			// 直接写入连续音频 (440Hz A音符) - 无需中间缓冲区
			sample_count := MAX_SAMPLES_PER_UPDATE * CHANNELS
			ring_buffer_produce(ring_output.samples, &ring_output.write_index, sample_count, 440.0)
		}

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
			rl.DrawText("PAUSED", screen_width / 2 - 40, screen_height / 2 - 20, 40, rl.WHITE)
		}

		rl.EndDrawing()
	}
	rl.UnloadTexture(bufferTexture)
	rl.CloseWindow()
}

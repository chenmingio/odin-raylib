package platform

import "base:runtime"
import "core:math"
import "core:os"
import "core:slice"
import rl "vendor:raylib"

Sample :: distinct i16 // 音频样本类型别名

// 音频配置常量
TARGET_FRAME_RATE :: 60 // 目标帧率
SAMPLE_RATE :: 48000 // 48kHz 采样率
CHANNELS :: 2 // 双声道
BITS_PER_SAMPLE :: 16 // 16位深度 (i16) 单个声道的位深度(sample类型就是i16)
BYTES_PER_SAMPLE :: BITS_PER_SAMPLE / 8 // 单个样本的字节数 = 2
BYTES_PER_FRAME :: BYTES_PER_SAMPLE * CHANNELS // 一帧的字节数 = 4

MAX_SAMPLES_PER_UPDATE :: SAMPLE_RATE / TARGET_FRAME_RATE // raylib的callback每次更新的样本数
MAX_SAMPLES_SECONDS :: 3 // 最大储存3秒的内容

// 全局音频状态
audio_time: f32 = 0.0 // 累计时间，用于生成连续声波
ring_output: RayLibSoundOutput

RayLibSoundOutput :: struct {
	samples:     []Sample, // 直接存储音频样本
	// 使用带符号的int更适合做index
	read_index:  int,
	write_index: int,
	//
	sample_rate: int,
	duration:    int,
}

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
	ring_buffer_consume(ring_output.samples, &ring_output.read_index, output_samples)
}

setup_audio :: proc() -> rl.AudioStream {
	rl.InitAudioDevice()
	rl.SetAudioStreamBufferSizeDefault(MAX_SAMPLES_PER_UPDATE)
	stream := rl.LoadAudioStream(SAMPLE_RATE, BITS_PER_SAMPLE, CHANNELS)
	rl.SetAudioStreamCallback(stream, audio_input_callback)
	rl.PlayAudioStream(stream) // 只在初始化时调用一次
	return stream
}

init_audio :: proc() -> rl.AudioStream {
	// 初始化环形音频缓冲区 - 3秒的音频数据
	buffer_size := SAMPLE_RATE * CHANNELS * MAX_SAMPLES_SECONDS
	ring_output = RayLibSoundOutput {
		samples     = make([]Sample, buffer_size),
		read_index  = 0,
		write_index = 0,
		sample_rate = SAMPLE_RATE,
		duration    = MAX_SAMPLES_SECONDS,
	}

	return setup_audio()
}

// 每帧更新音频
update_audio :: proc(is_paused: bool) {
	if !is_paused {
		// 每帧生成一帧的音频数据，避免过度生产
		sample_count := MAX_SAMPLES_PER_UPDATE * CHANNELS
		ring_buffer_produce(ring_output.samples, &ring_output.write_index, sample_count, 440.0)
	}
}

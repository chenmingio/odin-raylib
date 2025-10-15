package platform

import "core:os"

Sample :: distinct i16 // 音频样本类型别名

RayLibSoundOutput :: struct {
	samples:     []Sample, // 直接存储音频样本
	// 使用带符号的int更适合做index
	read_index:  int,
	write_index: int,
	//
	sample_rate: int,
	duration:    int,
}

RayLibState :: struct {
	total_size:         int,
	write_input_stream: os.Handle,
	read_input_stream:  os.Handle,
	is_recording:       bool,
	is_replaying:       bool,
}

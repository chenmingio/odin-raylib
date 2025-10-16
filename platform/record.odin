package platform

import "../game"
import "core:fmt"
import "core:os"

// 录制回放状态（对应 C 版本的 RayLibState 部分功能）
RayLibState :: struct {
	total_size:         int,
	write_input_stream: os.Handle,
	read_input_stream:  os.Handle,
	is_recording:       bool,
	is_replaying:       bool,
	game_memory_block:  rawptr,
}

// 开始录制输入
// 打开录制文件，设置为写模式，清空文件内容
start_recording :: proc(state: ^RayLibState, filename: string) {
	assert(!state.is_recording && !state.is_replaying, "不能同时录制和回放")

	handle, err := os.open(filename, os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o644)
	assert(err == os.ERROR_NONE, "打开录制文件失败")

	// 先保存整个游戏内存状态到文件开头
	os.write_ptr(handle, state.game_memory_block, state.total_size)

	state.write_input_stream = handle
	state.is_recording = true
}

// 停止录制
stop_recording :: proc(state: ^RayLibState) {
	assert(state.is_recording, "只能在录制状态下停止录制")
	os.close(state.write_input_stream)
	state.is_recording = false
}

// 录制一帧输入
record_input :: proc(state: ^RayLibState, input: ^game.Input) {
	assert(state.is_recording, "只能在录制状态下写入输入")
	os.write_ptr(state.write_input_stream, input, size_of(game.Input))
}

// 开始回放
start_replaying :: proc(state: ^RayLibState, filename: string) {
	assert(!state.is_recording && !state.is_replaying, "不能同时回放和录制")

	handle, err := os.open(filename, os.O_RDONLY)
	assert(err == os.ERROR_NONE, "打开回放文件失败")

	// 先恢复整个游戏内存状态到录制开始时的状态
	os.read_ptr(handle, state.game_memory_block, state.total_size)

	state.read_input_stream = handle
	state.is_replaying = true
}

// 停止回放
stop_replaying :: proc(state: ^RayLibState) {
	assert(state.is_replaying, "只能在回放状态下停止回放")
	os.close(state.read_input_stream)
	state.is_replaying = false
}

// 循环读取输入
loop_read_input :: proc(state: ^RayLibState, input: ^game.Input) {
	assert(state.is_replaying, "只能在回放状态下读取输入")

	bytes_read, _ := os.read_ptr(state.read_input_stream, input, size_of(game.Input))

	if bytes_read == 0 {
		// 到达文件末尾，重新开始回放循环
		// 1. 重新定位到文件开头
		os.seek(state.read_input_stream, 0, os.SEEK_SET)
		// 2. 重新恢复游戏内存状态到录制开始时的状态
		os.read_ptr(state.read_input_stream, state.game_memory_block, state.total_size)
		// 3. 现在文件指针已经在输入数据开头，读取第一个输入
		os.read_ptr(state.read_input_stream, input, size_of(game.Input))
	}
}

package playground
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"


AseRect :: struct {
	x, y, w, h: int,
}

AseFrame :: struct {
	frame:            AseRect,
	rotated:          bool,
	trimmed:          bool,
	spriteSourceSize: AseRect,
	sourceSize:       struct {
		w, h: int,
	},
	duration:         int, // ms
}

AseFrameTag :: struct {
	name:      string,
	from, to:  int,
	direction: string,
	// color 也可以要也可以不要
}

AseMeta :: struct {
	size:         struct {
		w, h: int,
	},
	scale:        string,
	frameTags:    []AseFrameTag,
	anchorOffset: struct {
		x, y: int,
	},
}

AseSpriteSheet :: struct {
	frames: map[string]AseFrame,
	meta:   AseMeta,
}

main :: proc() {
	file_path := "resources/Units/Units (aseprite)/Warrior.json"

	// 用 allocator 读取整个文件
	data, ok := os.read_entire_file(file_path)
	if !ok {
		fmt.println("failed to read file:", file_path)
		return
	}

	// data 本身就是 []u8
	bytes := data

	// 2) 反序列化
	sheet: AseSpriteSheet
	err := json.unmarshal(bytes, &sheet)
	if err != nil {
		fmt.println("unmarshal error:", err)
		return
	}

	// 打印几个东西验证
	fmt.println("tags:")
	for tag in sheet.meta.frameTags {
		fmt.printf("  %s: %d -> %d\n", tag.name, tag.from, tag.to)
	}

	fmt.println("one frame:")
	for name, frame in sheet.frames {
		fmt.printf(
			"  %s: (%d,%d,%d,%d), duration=%d\n",
			name,
			frame.frame.x,
			frame.frame.y,
			frame.frame.w,
			frame.frame.h,
			frame.duration,
		)
	}
}

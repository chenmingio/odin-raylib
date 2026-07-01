package game

import "core:fmt"
import "core:image"
import "core:strconv"
import "core:strings"

AseRect :: struct {
	x, y, w, h: i32,
}

AseFrame :: struct {
	//atlas 里的采样矩形：当前帧在 texture/atlas 内的位置和尺寸。
	frame:            AseRect,
	rotated:          bool,
	trimmed:          bool,
	//trim 后的可见 sprite 在原始帧画布里的位置和尺寸
	spriteSourceSize: AseRect,
	// trim 之前的原始帧画布尺寸
	sourceSize:       struct {
		w, h: int,
	},
	duration:         i32, // 当前动画帧的播放时长，单位是毫秒。
}

AseFrameTag :: struct {
	name:      string,
	from, to:  i32,
	direction: string,
	// color 也可以要也可以不要
}

AseMeta :: struct {
	size:      struct {
		w, h: i32,
	},
	scale:     string,
	frameTags: []AseFrameTag, //Aseprite 里给一段帧范围命名的标签；代码里会转换成动画 clip。
}

AseSpriteSheet :: struct {
	frames: map[string]AseFrame,
	meta:   AseMeta,
}

AnimClip :: struct {
	frames: [dynamic]AseFrame,
}

Animation :: struct {
	clips:           [EntityStatus]AnimClip, // 用枚举当下标的定长数组
	image:           ^image.Image,
	pivot_in_source: V2i,
}

// 提取frames的key（例如 Warrior #Attach 1 2.aseprite）里的index 2
get_frame_index_from_key :: proc(key: string) -> (int, bool) {
	parts := strings.split(key, " ")
	if len(parts) == 0 {
		return 0, false
	}

	last := parts[len(parts) - 1] // e.g. "14.aseprite"
	if !strings.has_suffix(last, ".aseprite") {
		return 0, false
	}

	num_str := last[:len(last) - len(".aseprite")] // "14"
	return strconv.parse_int(num_str, 10)
}

animation_from_ase_sprite_sheet :: proc(
	sheet: AseSpriteSheet,
	image: ^image.Image,
	pivot_in_source: V2i,
	prefix: string,
) -> Animation {
	result: Animation
	result.image = image
	result.pivot_in_source = pivot_in_source

	for tag in sheet.meta.frameTags {
		status := name_to_entity_status(tag.name)
		clip := &result.clips[status]

		for i in 0 ..= (tag.to - tag.from) {
			key := fmt.tprintf("%s #%s %d.aseprite", prefix, tag.name, i)
			anim_frame, ok := sheet.frames[key]
			assert(ok, "frame not found")

			n, err := append(&clip.frames, anim_frame)
			assert(err == nil, "append failed")
		}

		assert(len(clip.frames) > 0)
	}

	return result
}

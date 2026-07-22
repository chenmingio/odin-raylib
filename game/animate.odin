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
	clips:            [EntityStatus]AnimClip, // 用枚举当下标的定长数组
	image:            ^image.Image,
	anchor_in_source: V2i,
}

AseSpriteAsset :: struct {
	sheet: AseSpriteSheet,
	image: ^image.Image,
}

Sprite :: struct {
	image:           ^image.Image,
	frame_size:      V2i, // image里多大的一块
	frame_pos:       V2i, // sprite距离image左上角的距离
	anchor_in_frame: V2i, // 锚点距离image左上角的距离
}

sprite_from_assets :: proc(assets: AseSpriteAsset, key: string, anchor_in_source: V2i) -> Sprite {
	anim_frame, ok := assets.sheet.frames[key]
	assert(ok, "frame not found")

	source_rect_size := V2i{anim_frame.frame.w, anim_frame.frame.h}
	source_rect_pos := V2i{anim_frame.frame.x, anim_frame.frame.y}
	trim_offset_on_source := V2i{anim_frame.spriteSourceSize.x, anim_frame.spriteSourceSize.y}
	return Sprite {
		assets.image,
		source_rect_size,
		source_rect_pos,
		anchor_in_source - trim_offset_on_source,
	}
}

animation_from_assets :: proc(
	assets: AseSpriteAsset,
	prefix: string,
	anchor_in_source: V2i,
) -> Animation {
	result: Animation
	result.image = assets.image
	result.anchor_in_source = anchor_in_source

	for tag in assets.sheet.meta.frameTags {
		status, ok := name_to_entity_status(tag.name)
		if !ok {continue}
		clip := &result.clips[status]

		for i in 0 ..= (tag.to - tag.from) {
			key := fmt.tprintf("%s #%s %d.aseprite", prefix, tag.name, i)
			anim_frame, ok := assets.sheet.frames[key]
			assert(ok, "frame not found")

			n, err := append(&clip.frames, anim_frame)
			assert(err == nil, "append failed")
		}

		assert(len(clip.frames) > 0)
	}

	return result
}

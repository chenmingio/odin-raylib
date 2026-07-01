# Draw Image / Animation 设计笔记

这份文档解释 `resources/Units/Warrior.json` 这类 Aseprite 导出的
JSON 文件是什么意思，以及代码如何根据这些数据，从 texture atlas 里找到目标
方块，再把它画到 backbuffer 上。

这里有三件事必须分开看：

1. **从 texture atlas 里取哪一块图？**
2. **把这块图画到 buffer 的哪里？**
3. **如果 Aseprite trim 掉了透明边缘，怎么让动画帧不乱跳？**

之前容易混乱，就是因为 `frame`、`spriteSourceSize`、实体 pivot、
buffer 坐标都混在了一起。

## 术语表

### Aseprite / TexturePacker JSON 术语

`frame` / `spriteSourceSize` / `sourceSize` 这三个字段基本沿用
TexturePacker/Aseprite JSON 生态：`frame` 是 texture/atlas 内的位置
和尺寸，`spriteSourceSize` 是裁剪后帧在原图里的位置和尺寸，
`sourceSize` 是原始图尺寸。

| 术语 | 含义 |
|---|---|
| `sprite` | 2D 游戏里被绘制进场景的位图对象。 |
| `sprite sheet` | 把同一个 sprite 的多个动画帧放在一张大图里。 |
| `texture atlas` / `atlas` | 把多个 sprite、图片或动画帧打包进一张 texture；渲染时从里面取子矩形。 |
| `frame` | atlas 里的采样矩形：当前帧在 texture/atlas 内的位置和尺寸。 |
| `sourceSize` | trim 之前的原始帧画布尺寸。 |
| `spriteSourceSize` | trim 后的可见 sprite 在原始帧画布里的位置和尺寸。 |
| `trimmed` | 是否裁掉了透明边缘。 |
| `rotated` | 打包进 atlas 时，这个 frame 是否被旋转。当前代码暂不支持 rotated frame。 |
| `duration` | 当前动画帧的播放时长，单位是毫秒。 |
| `frame tag` | Aseprite 里给一段帧范围命名的标签；代码里会转换成动画 clip。 |

### 项目代码术语建议

下面是当前代码名到统一术语的映射。后文用“建议名字”描述模型；旧名字只在
这张对照表里保留，方便后续重命名代码时逐项对应。

| 当前名字 | 建议名字 | 含义 |
|---|---|---|
| `anchor_buffer_pos` | `entity_pivot_buffer_pos` | 实体/精灵的目标 pivot 在 buffer 上的位置。 |
| `anchorOffset` | `pivot_in_source` | pivot 在未裁剪原始帧里的像素坐标。 |
| `clips` | `clip_frames` | 当前动画片段的帧列表。 |
| `frame` | `anim_frame` | Aseprite JSON 的单帧数据。 |
| `sprite_size` | `source_rect_size` | atlas 中实际被绘制的裁剪后 sprite 尺寸。 |
| `atlas_offset` | `source_rect_pos` | atlas 内采样矩形左上角。 |
| `source_frame_to_sprite` | `trimmed_offset_in_source` | 裁剪后 sprite 在原始未裁剪帧里的偏移。 |
| `buffer_draw_pos` | `sprite_dest_top_left` | 最终绘制到 buffer 的左上角。 |

### 核心图示

`frame` 描述 atlas 里的采样矩形，也就是从 `Warrior.png` 这张大图里读哪一块。

```text
Warrior.png / texture atlas

(0,0)
+--------------------------------------------------+
| frame.x = 0, frame.y = 0                         |
| v                                                |
| +-------------------+                            |
| | 当前帧 trimmed 图 |  frame.w = 79              |
| |                   |  frame.h = 89              |
| +-------------------+                            |
|                                                  |
+--------------------------------------------------+
```

`sourceSize` 描述 trim 之前的原始帧画布。

```text
原始 Aseprite frame，trim 之前

(0,0)
+--------------------------------+
|                                |
|                                |
|        +----------------+      |
|        |   可见 sprite  |      |
|        +----------------+      |
|                                |
|                                |
+--------------------------------+
                         192x192
```

`spriteSourceSize` 描述 trim 后的可见 sprite 在原始帧画布里的位置和尺寸。

```text
原始 192x192 frame

(0,0)
+--------------------------------+
|                                |
|                                |
|      spriteSourceSize.y = 48   |
|              v                 |
|      +-------------------+     |
|      | 当前帧 trimmed 图 |     |
|      | 79 x 89           |     |
|      +-------------------+     |
|      ^                         |
|      spriteSourceSize.x = 62   |
|                                |
+--------------------------------+
```

`pivot_in_source` 是原始帧坐标系里的固定角色 pivot；
`entity_pivot_buffer_pos` 是这个 pivot 在 buffer 上要对齐到的位置。

```text
原始 source frame，固定坐标系

(0,0)
+--------------------------------+
|                                |
|      +-------------------+     |
|      |                   |     |
|      | visible sprite    |     |
|      |                   |     |
|      +-------------------+     |
|             x                  |
|             ^                  |
|             pivot_in_source    |
|                                |
+--------------------------------+
```

最终绘制位置：

```text
sprite_dest_top_left =
    entity_pivot_buffer_pos +
    trimmed_offset_in_source -
    pivot_in_source
```

动画渲染时同时涉及三个不同的矩形：

```text
1. source frame
   Aseprite trim 前的原始帧画布，由 sourceSize 描述。

2. source rect
   texture atlas 里的采样矩形，由 frame 描述。

3. destination rect
   buffer 上最终写入的矩形，由 sprite_dest_top_left + source_rect_size 描述。
```

### 参考资料

- Wikipedia: Sprite 是 2D bitmap 被集成进更大场景的图形对象。
  https://en.wikipedia.org/wiki/Sprite_(computer_graphics)
- Aseprite 文档：使用 `sprite sheet`、`frames`、`tags`、`texture atlas`
  等术语描述导入导出。
  https://www.aseprite.org/docs/sprite-sheet/
- TexturePacker/Felgo 文档：`frame`、`spriteSourceSize`、`sourceSize`
  的含义和 Aseprite JSON 基本一致。
  https://felgo.com/doc/howto-texture-packer/
- Unity 2D 文档：`pivot` 是 sprite 的坐标原点/主要锚点。
  https://docs.unity3d.com/560/Documentation/Manual/SpriteEditor.html


## `Warrior.json` 里的字段

以 `Warrior #Idle 0.aseprite` 为例：

```json
"Warrior #Idle 0.aseprite": {
  "frame": {
    "x": 0,
    "y": 0,
    "w": 79,
    "h": 89
  },
  "rotated": false,
  "trimmed": true,
  "spriteSourceSize": {
    "x": 62,
    "y": 48,
    "w": 79,
    "h": 89
  },
  "sourceSize": {
    "w": 192,
    "h": 192
  },
  "duration": 100
}
```

### `frame`

`frame` 描述的是：**当前帧在最终 texture atlas 图片里的位置**。

也就是从 `Warrior.png` 这张大图里裁哪一块。图示见术语表里的
`frame` 核心图示。

所以：

```text
frame.x / frame.y = 在 atlas 里的左上角
frame.w / frame.h = atlas 里这一帧的宽高
```

在代码里对应：

```odin
source_rect_size := V2i{anim_frame.frame.w, anim_frame.frame.h}
source_rect_pos := V2i{anim_frame.frame.x, anim_frame.frame.y}
```

`frame` 只管“从 atlas 里读哪里”，不管“画到屏幕哪里”。


### `sourceSize`

`sourceSize` 是：**Aseprite trim 之前，原始动画帧的画布大小**。

这个 Warrior 资源里是：

```json
"sourceSize": {
  "w": 192,
  "h": 192
}
```

也就是原始每一帧是 `192x192` 的透明画布。人物真正可见的部分并没有这么大。
图示见术语表里的 `sourceSize` 核心图示。

注意：`sourceSize.h = 192` 不等于“人物脚底在 y=192”。  
它只是原始透明画布的高度。


### `spriteSourceSize`

`spriteSourceSize` 是：**trim 后的 visible sprite，在原始 `sourceSize` 画布里的位置**。

例子：

```json
"spriteSourceSize": {
  "x": 62,
  "y": 48,
  "w": 79,
  "h": 89
}
```

图示见术语表里的 `spriteSourceSize` 核心图示。

所以：

```text
spriteSourceSize.x / y = trimmed 图在原始画布里的左上角
spriteSourceSize.w / h = trimmed 图在原始画布里的大小
```

通常在没有 rotated 的情况下：

```text
spriteSourceSize.w == frame.w
spriteSourceSize.h == frame.h
```


### `trimmed`

`trimmed: true` 表示 Aseprite 把透明边缘裁掉了。

裁掉以后 sprite sheet 更小，但是动画定位会多一个问题：

```text
如果只按 frame.w / frame.h 直接画，
每一帧的可见图大小和左上角都可能不同，
人物会看起来抖动。
```

`spriteSourceSize` 就是用来描述“这块 trimmed sprite 原本在 192x192 画布里的哪里”。


### `rotated`

`rotated: false` 表示 atlas 里的这块图没有被旋转。

当前渲染代码默认 `rotated == false`。如果以后 Aseprite 导出 rotated frame，
`draw_image_corp` 需要额外支持旋转采样。


### `duration`

`duration` 是这一帧播放多久，单位是毫秒。

```json
"duration": 100
```

表示这一帧显示 100ms。


## 为什么有了 `frame` 还需要 `sourceSize` 和 `spriteSourceSize`

如果只是静态画一张图，`frame` 基本够用：

```text
从 atlas 里取 frame 这块
画到 buffer 某个位置
```

但是动画不是只关心“画什么”，还关心“每一帧在同一个角色坐标系里应该站在哪里”。

`frame` 只回答：

```text
我要从 atlas 里读哪一块像素？
```

它不回答：

```text
这块 trimmed sprite 在原始动画帧里原本在哪里？
角色的脚底/中心/武器挂点在哪里？
这一帧和上一帧如何保持稳定不抖？
```

`sourceSize + spriteSourceSize` 就是为了解决这个问题。

### 只用 `frame` 会丢失原始帧坐标系

Aseprite trim 之后，每一帧可见区域的大小和左上角都可能不同：

```text
原始 192x192 frame

Idle 0:
+--------------------------+
|                          |
|      +-------------+     |
|      |   人物      |     |
|      +-------------+     |
|                          |
+--------------------------+

Idle 3:
+--------------------------+
|                          |
|    +----------------+    |
|    |     人物       |    |
|    +----------------+    |
|                          |
+--------------------------+
```

trim 后存进 atlas，可能变成：

```text
Idle 0: 79 x 89
Idle 3: 81 x 86
Run 4 : 93 x 91
Attack: 120 x 104
```

如果只用 `frame`，并且每一帧都从同一个 `sprite_dest_top_left` 开始画：

```text
sprite_dest_top_left
  v
  +-------------+     第一帧
  | 人物        |
  +-------------+

sprite_dest_top_left
  v
  +----------------+  第二帧，因为 trim 后的图大小和内容位置不同
  |   人物         |  看起来可能会跳
  +----------------+
```

这时人物可能会抖动，因为你已经不知道 trimmed 图在原始 `192x192` 画布里的位置。


### `spriteSourceSize` 保留了 trimmed 图在原始帧里的位置

例如：

```json
"frame": {
  "w": 79,
  "h": 89
},
"spriteSourceSize": {
  "x": 62,
  "y": 48,
  "w": 79,
  "h": 89
},
"sourceSize": {
  "w": 192,
  "h": 192
}
```

图示见术语表里的 `spriteSourceSize` 核心图示。

所以：

```text
frame
= 这块图在 atlas 里的位置

spriteSourceSize
= 这块图原本在 source frame 里的位置

sourceSize
= 原始动画帧统一坐标系的大小
```


### 用 `spriteSourceSize` 还原到固定的 source pivot

对角色动画来说，我们通常希望找到一个稳定的点，比如：

```text
脚底中心
身体中心
武器挂点
```

这个点不应该每一帧重新根据 trimmed sprite 的红框来算。否则如果角色跳起来、
被击飞、攻击时身体在原始帧里移动，代码会把它重新拉回 pivot，动画里的位移
就丢了。

更合理的做法是：在原始 `sourceSize` 坐标系里选一个固定点。Warrior 的 Idle
帧底部中心大约是 `V2i{101, 137}`，当前代码在视觉上微调为：

```odin
pivot_in_source := V2i{101, 130}
```

图示见术语表里的 `pivot_in_source` 核心图示。

`spriteSourceSize.x/y` 的作用是：告诉我们当前 trimmed sprite 的左上角在
这个原始 source frame 里的哪里。

所以画到 buffer 时：

```odin
trimmed_offset_in_source := V2i{frame.spriteSourceSize.x, frame.spriteSourceSize.y}

sprite_dest_top_left =
    entity_pivot_buffer_pos +
    trimmed_offset_in_source -
    pivot_in_source
```

这里的含义是：

```text
entity_pivot_buffer_pos 是游戏世界里实体的位置落到屏幕上的点
pivot_in_source 是素材原始 frame 里的固定角色 pivot，当前 Warrior 使用 V2i{101, 130}
spriteSourceSize.xy 是当前 trimmed sprite 相对原始 frame 的左上角

让 pivot_in_source 对齐到游戏里的 entity_pivot_buffer_pos，
同时保留当前帧在原始 source frame 里的位移。
```

如果角色反向绘制，像素会在 `draw_image_corp` / `blend` 阶段水平翻转。
这时不能直接复用正向的 `pivot_in_source.x`，否则视觉上的 pivot 会落在翻转前
的位置。需要在完整的原始 `sourceSize` 坐标系里镜像 pivot：

```odin
pivot_in_source := animation.pivot_in_source
if reverse {
    pivot_in_source.x = i32(anim_frame.sourceSize.w) - animation.pivot_in_source.x
}
```

注意这里用的是 `sourceSize.w`，不是 `spriteSourceSize.w` 或 `frame.w`。
原因是 `pivot_in_source` 定义在 trim 之前的原始 source frame 里；反向时也要
在同一个完整坐标系里做镜像，不能用 trimmed sprite 的宽度来算。

所以这几个字段的职责可以总结成：

```text
frame
= 我从 atlas 里裁哪一块

spriteSourceSize
= 这块裁出来的小图，原本在 source frame 的哪里

sourceSize
= 原始动画帧的统一坐标系有多大

pivot_in_source
= 我在这个统一坐标系里选的固定角色 pivot
```


## 三个不同的方块

动画渲染时，至少有三个方块：

```text
1. 原始 source frame
2. texture atlas 里的 source rect
3. buffer 上的 destination rect
```

### 1. 原始 source frame

这是 Aseprite 里 trim 之前的 `192x192` 画布。
这个方块由 `sourceSize` 描述。图示见术语表里的 `sourceSize` 核心图示。


### 2. texture atlas 里的 source rect

这是 `Warrior.png` 里实际存储的 trimmed 小图。
这个方块由 `frame` 描述。图示见术语表里的 `frame` 核心图示。

```text
frame.x, frame.y, frame.w, frame.h
```


### 3. buffer 上的 destination rect

这是软件渲染器最终要画到屏幕 buffer 上的方块。

这个方块由代码算出来：

```odin
sprite_dest_top_left // buffer 上的左上角
source_rect_size     // 通常是 frame.w / frame.h
```


## `draw_image_corp` 怎么找到目标方块

`draw_image_corp` 的输入大概是：

```odin
draw_image_corp(
    buffer_pos,
    img,
    buffer,
    source_rect_size = V2i{anim_frame.frame.w, anim_frame.frame.h},
    source_rect_pos = V2i{anim_frame.frame.x, anim_frame.frame.y},
)
```

这里有两个坐标空间：

```text
buffer_pos      = 画到 buffer 的哪里
source_rect_pos = 从 atlas 的哪里开始读
```

### 第一步：在 buffer 上确定目标方块

```odin
sprite_rect := Rectangle {
    min = buffer_pos,
    max = buffer_pos + source_rect_size,
}
```

图解：

```text
buffer

(0,0)
+--------------------------------------------------+
|                                                  |
|    buffer_pos                                    |
|       v                                          |
|       +-------------------+                      |
|       | sprite_rect       |                      |
|       +-------------------+                      |
|                                                  |
+--------------------------------------------------+
```


### 第二步：和屏幕边界求交集

如果 sprite 有一部分在屏幕外面，不能直接画完整方块。

```odin
draw_rect, ok := intersect_rect(sprite_rect, buffer_rect)
```

图解：

```text
buffer

+-----------------------------+
|                +------------+------+
|                | draw_rect  |      |
|                +------------+      |
+-----------------------------+      |
                 | sprite_rect       |
                 +-------------------+
```

`draw_rect` 是真正要写入 buffer 的区域。


### 第三步：从 buffer 像素反推 source 像素

循环 buffer 上的每一行：

```odin
for ty in draw_rect.min.y ..< draw_rect.max.y {
    sy := ty - buffer_pos.y + source_rect_pos.y
    sx := draw_rect.min.x - buffer_pos.x + source_rect_pos.x
}
```

含义：

```text
ty - buffer_pos.y
= 当前 buffer y 在 sprite_rect 内部的局部 y

draw_rect.min.x - buffer_pos.x
= 当前这一行起点在 sprite_rect 内部的局部 x

source_rect_pos.x / y
= 当前帧在 atlas 里的左上角
```

所以：

```text
source_x = source_rect_pos.x + local_sprite_x
source_y = source_rect_pos.y + local_sprite_y
```

也就是：

```text
buffer 上第 N 个像素
对应 atlas 里 source_rect_pos 后面的第 N 个像素
```


## 动画帧怎么从 JSON 进入代码

JSON 里的 key 长这样：

```text
Warrior #Idle 0.aseprite
Warrior #Idle 1.aseprite
Warrior #Run 0.aseprite
```

Aseprite 还会导出 frame tags，比如 `Idle`、`Run`、`Attack 1`。

代码里：

```odin
status := name_to_entity_status(tag.name)
clip := &result.clips[status]
```

然后根据 tag 里的帧范围，重新拼出 key：

```odin
key := fmt.tprintf("%s #%s %d.aseprite", prefix, tag.name, i)
anim_frame := sheet.frames[key]
append(&clip.frames, anim_frame)
```

最后得到：

```text
Animation.clips[EntityStatus.Idle] = Idle 的所有 AseFrame
Animation.clips[EntityStatus.Run]  = Run 的所有 AseFrame
```

运行时：

```odin
clip_frames := animation.clips[entity.status].frames
anim_frame := clip_frames[entity.anim_frame_idx]
```

然后用：

```odin
entity.anim_time += i32(dt * 1000)
```

累积播放时间。如果超过当前帧的 `duration`，就切到下一帧。


## 世界坐标怎么变成 buffer 坐标

实体的位置是世界坐标：

```odin
entity.pos: WorldPosition
```

先算出相机相对位置：

```odin
rel_pos := relative_pos(entity.pos, game_state.camera_pos)
```

然后变成 buffer 坐标：

```odin
entity_pivot_buffer_pos := rel_pos_to_buffer_pos(rel_pos, image_buffer)
```

当前公式：

```text
buffer_x = buffer.width  / 2 + rel.x * SCALE
buffer_y = buffer.height / 2 - rel.y * SCALE
```

注意 y 方向是负号，因为：

```text
世界坐标：y 向上
屏幕坐标：y 向下
```

图解：

```text
世界 / 相机相对坐标

          +y
           ^
           |
           |
 -x <------+------> +x
           |
           v
          -y


buffer 坐标

(0,0) +----------------------> +x
      |
      |
      |
      v
     +y
```

`entity_pivot_buffer_pos` 是实体 pivot 在 buffer 上的位置。当前项目里，它更像
“实体脚底中心”。


## 实体 body box 怎么算

实体有一个逻辑尺寸：

```odin
entity.size: V2 // 单位：米
```

换成像素：

```odin
entity_size_px := V2i {
    i32(meter_to_pixel(entity.size.x)),
    i32(meter_to_pixel(entity.size.y)),
}
```

从 pivot 得到 body 左上角：

```odin
body_top_left := entity_top_left_from_pivot(entity_pivot_buffer_pos, entity_size_px)
```

当前公式：

```odin
body_top_left = entity_pivot_buffer_pos - V2i{size_px.x / 2, size_px.y}
```

图解：

```text
entity_pivot_buffer_pos
      x
      |
      | size_px.y
      |
+-----+-----+
|           |
| body box  |
|           |
+-----------+

body_top_left = entity_pivot_buffer_pos - (width / 2, height)
```


## 动画放置为什么容易错

裁图和放置是两件事。

```text
frame / source_rect_pos
= 决定从 Warrior.png 读哪一块

sprite_dest_top_left
= 决定把这块图画到 buffer 的哪里
```

如果人物形状完整、动画帧内容正确，说明：

```text
frame 正确
source_rect_pos 正确
source_rect_size 正确
draw_image_corp 的像素复制正确
```

如果整个人位置偏了，问题通常在：

```text
sprite_dest_top_left 怎么算
```


## 当前最终动画放置模型

当前采用 **source frame 固定 pivot 模型**。

核心原则：

```text
entity pivot
= 游戏世界里的实体 pivot，落到屏幕上以后是 entity_pivot_buffer_pos

pivot_in_source
= 原始 source frame 坐标系里的固定角色 pivot

spriteSourceSize.xy
= 当前 trimmed sprite 左上角在原始 source frame 里的位置
```

代码里的公式是：

```odin
pivot_in_source := animation.pivot_in_source
trimmed_offset_in_source := V2i{anim_frame.spriteSourceSize.x, anim_frame.spriteSourceSize.y}

if reverse {
    pivot_in_source.x = i32(anim_frame.sourceSize.w) - animation.pivot_in_source.x
}

sprite_dest_top_left =
    entity_pivot_buffer_pos +
    trimmed_offset_in_source -
    pivot_in_source
```

含义：

```text
把原始 source frame 里的固定 pivot_in_source 对齐到 entity pivot，
再根据 spriteSourceSize.xy 找到当前 trimmed sprite 的左上角。
```

图示见术语表里的 `pivot_in_source` 核心图示。

画到 buffer 时：

```text
buffer

entity_pivot_buffer_pos
        x
        ^
        |
让 pivot_in_source 对齐到这里

sprite_dest_top_left =
    entity_pivot_buffer_pos + spriteSourceSize.xy - pivot_in_source
```

这个模型把概念分开了：

```text
entity pivot 负责世界/屏幕位置
pivot_in_source 负责素材原始 frame 内部的固定角色 pivot
spriteSourceSize 负责 trim 还原
frame 负责 atlas 裁图
```

这个模型的好处是：如果某一帧里角色真的跳起、后仰、攻击前探，这个位移会体
现在 `spriteSourceSize.x/y` 里。代码不会每帧重新用 trimmed sprite 的红框底
部去对齐 pivot，所以不会把动画里的真实位移抹掉。


## 排错时怎么看

如果之后动画位置又不对，先分清是哪一层错：

1. 人物形状不完整、裁错帧：
   检查 `frame`、`source_rect_size`、`source_rect_pos`、`draw_image_corp`。

2. 人物形状正确，但整体位置偏：
   检查 `entity_pivot_buffer_pos`、`pivot_in_source`、`spriteSourceSize.xy` 到 `sprite_dest_top_left`
   的公式。

3. body box 正确，动画整体偏：
   世界坐标和 body 计算大概率没问题，重点看 `pivot_in_source` 是否需要调整。

4. 某些动作帧突然跳动：
   先确认这是美术帧在原始 source frame 里的真实位移，还是 JSON 里的
   `spriteSourceSize.x/y` 不连续。

当前这条链路应该保持：

```text
WorldPosition
-> relative_pos
-> rel_pos_to_buffer_pos
-> entity_pivot_buffer_pos
-> entity_pivot_buffer_pos + spriteSourceSize.xy - pivot_in_source
-> sprite_dest_top_left
```

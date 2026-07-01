# Draw Image / Animation 设计笔记

这份文档解释 `resources/Units/Warrior.json` 这类 Aseprite 导出的
JSON 文件是什么意思，以及代码如何根据这些数据，从 spritesheet 里找到目标
方块，再把它画到 backbuffer 上。

这里有三件事必须分开看：

1. **从 spritesheet 里取哪一块图？**
2. **把这块图画到 buffer 的哪里？**
3. **如果 Aseprite trim 掉了透明边缘，怎么让动画帧不乱跳？**

之前容易混乱，就是因为 `frame`、`spriteSourceSize`、实体 anchor、
buffer 坐标都混在了一起。


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

`frame` 描述的是：**当前帧在最终 spritesheet 图片里的位置**。

也就是从 `Warrior.png` 这张大图里裁哪一块。

```text
Warrior.png / spritesheet

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

所以：

```text
frame.x / frame.y = 在图集里的左上角
frame.w / frame.h = 图集里这一帧的宽高
```

在代码里对应：

```odin
sprite_size := V2i{frame.frame.w, frame.frame.h}
atlas_offset := V2i{frame.frame.x, frame.frame.y}
```

`frame` 只管“从图集里读哪里”，不管“画到屏幕哪里”。


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

```text
原始 Aseprite frame，trim 之前

(0,0)
+--------------------------------+
|                                |
|                                |
|        +----------------+      |
|        |   可见人物     |      |
|        +----------------+      |
|                                |
|                                |
+--------------------------------+
                         192x192
```

注意：`sourceSize.h = 192` 不等于“人物脚底在 y=192”。  
它只是原始透明画布的高度。


### `spriteSourceSize`

`spriteSourceSize` 是：**trim 后的小图，在原始 `sourceSize` 画布里的位置**。

例子：

```json
"spriteSourceSize": {
  "x": 62,
  "y": 48,
  "w": 79,
  "h": 89
}
```

意思是：

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
                         192x192
```

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

裁掉以后 spritesheet 更小，但是动画定位会多一个问题：

```text
如果只按 frame.w / frame.h 直接画，
每一帧的可见图大小和左上角都可能不同，
人物会看起来抖动。
```

`spriteSourceSize` 就是用来描述“这块 trimmed 图原本在 192x192 画布里的哪里”。


### `rotated`

`rotated: false` 表示图集里的这块图没有被旋转。

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
从 spritesheet 里取 frame 这块
画到 buffer 某个位置
```

但是动画不是只关心“画什么”，还关心“每一帧在同一个角色坐标系里应该站在哪里”。

`frame` 只回答：

```text
我要从 spritesheet 里读哪一块像素？
```

它不回答：

```text
这块 trimmed 图在原始动画帧里原本在哪里？
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

trim 后存进 spritesheet，可能变成：

```text
Idle 0: 79 x 89
Idle 3: 81 x 86
Run 4 : 93 x 91
Attack: 120 x 104
```

如果只用 `frame`，并且每一帧都从同一个 `draw_pos` 开始画：

```text
draw_pos
  v
  +-------------+     第一帧
  | 人物        |
  +-------------+

draw_pos
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

表示：

```text
原始 192x192 source frame

(0,0)
+--------------------------------+
|                                |
|      spriteSourceSize.y = 48   |
|              v                 |
|      +-------------------+     |
|      | frame 这块图      |     |
|      | 79 x 89           |     |
|      +-------------------+     |
|      ^                         |
|      spriteSourceSize.x = 62   |
|                                |
+--------------------------------+
```

所以：

```text
frame
= 这块图在 spritesheet 里的位置

spriteSourceSize
= 这块图原本在 source frame 里的位置

sourceSize
= 原始动画帧统一坐标系的大小
```


### 用 `spriteSourceSize` 还原到固定的 source anchor

对角色动画来说，我们通常希望找到一个稳定的点，比如：

```text
脚底中心
身体中心
武器挂点
```

这个点不应该每一帧重新根据 trimmed sprite 的红框来算。否则如果角色跳起来、
被击飞、攻击时身体在原始帧里移动，代码会把它重新拉回 anchor，动画里的位移
就丢了。

更合理的做法是：在原始 `sourceSize` 坐标系里选一个固定点，比如 Warrior
素材里估算脚底中心是：

```odin
source_anchor := V2i{101, 137}
```

图解：

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
|             source_anchor      |
|                                |
+--------------------------------+
```

`spriteSourceSize.x/y` 的作用是：告诉我们当前 trimmed sprite 的左上角在
这个原始 source frame 里的哪里。

所以画到 buffer 时：

```odin
draw_pos =
    anchor_buffer_pos +
    V2i{frame.spriteSourceSize.x, frame.spriteSourceSize.y} -
    source_anchor
```

这里的含义是：

```text
anchor_buffer_pos 是游戏世界里实体的位置落到屏幕上的点
source_anchor 是素材原始 frame 里的固定角色锚点
spriteSourceSize.xy 是当前 trimmed sprite 相对原始 frame 的左上角

让 source_anchor 对齐到游戏里的 anchor_buffer_pos，
同时保留当前帧在原始 source frame 里的位移。
```

所以这几个字段的职责可以总结成：

```text
frame
= 我从图集里裁哪一块

spriteSourceSize
= 这块裁出来的小图，原本在 source frame 的哪里

sourceSize
= 原始动画帧的统一坐标系有多大

source_anchor
= 我在这个统一坐标系里选的固定角色锚点
```


## 三个不同的方块

动画渲染时，至少有三个方块：

```text
1. 原始 source frame
2. spritesheet 里的 atlas frame
3. buffer 上的 destination rect
```

### 1. 原始 source frame

这是 Aseprite 里 trim 之前的 `192x192` 画布。

```text
source frame

(0,0)
+--------------------------------+
|                                |
|      +-------------------+     |
|      | trimmed sprite    |     |
|      +-------------------+     |
|                                |
+--------------------------------+
                         192x192
```

这个方块由 `sourceSize` 描述。


### 2. spritesheet 里的 atlas frame

这是 `Warrior.png` 里实际存储的 trimmed 小图。

```text
spritesheet

(0,0)
+--------------------------------------------------+
| +-------------------+ +-------------------+      |
| | Idle 0            | | Idle 1            |      |
| +-------------------+ +-------------------+      |
|                                                  |
+--------------------------------------------------+
```

这个方块由 `frame` 描述：

```text
frame.x, frame.y, frame.w, frame.h
```


### 3. buffer 上的 destination rect

这是软件渲染器最终要画到屏幕 buffer 上的方块。

```text
backbuffer

(0,0)
+--------------------------------------------------+
|                                                  |
|       draw_pos                                   |
|          v                                       |
|          +-------------------+                   |
|          | visible sprite    |                   |
|          +-------------------+                   |
|                                                  |
+--------------------------------------------------+
```

这个方块由代码算出来：

```odin
draw_pos    // buffer 上的左上角
sprite_size // 通常是 frame.w / frame.h
```


## `draw_image_corp` 怎么找到目标方块

`draw_image_corp` 的输入大概是：

```odin
draw_image_corp(
    buffer_pos,
    img,
    buffer,
    sprite_size = V2i{frame.frame.w, frame.frame.h},
    atlas_offset = V2i{frame.frame.x, frame.frame.y},
)
```

这里有两个坐标空间：

```text
buffer_pos   = 画到 buffer 的哪里
atlas_offset = 从 spritesheet 的哪里开始读
```

### 第一步：在 buffer 上确定目标方块

```odin
sprite_rect := Rectangle {
    min = buffer_pos,
    max = buffer_pos + sprite_size,
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
    sy := ty - buffer_pos.y + atlas_offset.y
    sx := draw_rect.min.x - buffer_pos.x + atlas_offset.x
}
```

含义：

```text
ty - buffer_pos.y
= 当前 buffer y 在 sprite_rect 内部的局部 y

draw_rect.min.x - buffer_pos.x
= 当前这一行起点在 sprite_rect 内部的局部 x

atlas_offset.x / y
= 当前帧在 spritesheet 里的左上角
```

所以：

```text
source_x = atlas_offset.x + local_sprite_x
source_y = atlas_offset.y + local_sprite_y
```

也就是：

```text
buffer 上第 N 个像素
对应 spritesheet 里 atlas_offset 后面的第 N 个像素
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
frame := sheet.frames[key]
append(&clip.frames, frame)
```

最后得到：

```text
Animation.clips[EntityStatus.Idle] = Idle 的所有 AseFrame
Animation.clips[EntityStatus.Run]  = Run 的所有 AseFrame
```

运行时：

```odin
clips := animation.clips[entity.status].frames
frame := clips[entity.anim_frame_idx]
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
anchor_buffer_pos := rel_pos_to_buffer_pos(rel_pos, image_buffer)
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

`anchor_buffer_pos` 是实体 anchor 在 buffer 上的位置。当前项目里，它更像
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

从 anchor 得到 body 左上角：

```odin
body_top_left := entity_top_left_from_anchor(anchor_buffer_pos, entity_size_px)
```

当前公式：

```odin
body_top_left = anchor_buffer_pos - V2i{size_px.x / 2, size_px.y}
```

图解：

```text
anchor_buffer_pos
      x
      |
      | size_px.y
      |
+-----+-----+
|           |
| body box  |
|           |
+-----------+

body_top_left = anchor - (width / 2, height)
```


## 动画放置为什么容易错

裁图和放置是两件事。

```text
frame / atlas_offset
= 决定从 Warrior.png 读哪一块

draw_pos
= 决定把这块图画到 buffer 的哪里
```

如果人物形状完整、动画帧内容正确，说明：

```text
frame 正确
atlas_offset 正确
sprite_size 正确
draw_image_corp 的像素复制正确
```

如果整个人位置偏了，问题通常在：

```text
draw_pos 怎么算
```


## 当前调试标记

当前 debug overlay 的含义：

```text
白色十字 = anchor_buffer_pos
蓝色框   = body / collision box
黑色十字 = draw_pos，也就是 sprite 画到 buffer 的左上角
红色框   = 实际 trimmed sprite 在 buffer 上的方块
```

如果看到：

```text
白色十字在屏幕中心
蓝色框正确包住实体逻辑 body
红色框里是完整且正确的动画
黑色十字在红框左上角
红框整体相对蓝框/白十字偏了
```

那么可以判断：

```text
世界坐标 -> buffer 坐标是对的
body_top_left 是对的
spritesheet 裁图是对的
draw_image_corp 是对的

剩下的问题只是：
sprite 应该相对 entity anchor 放在哪里
```


## 两种动画放置模型

### 模型 A：以 body top-left 为基准

旧代码接近这个模型：

```odin
draw_pos =
    body_top_left +
    animation.anchorOffset -
    V2i{frame.spriteSourceSize.x, frame.spriteSourceSize.y}
```

含义：

```text
先找到实体 body 的左上角，
再根据 spriteSourceSize 把 trimmed sprite 挪回原始 frame 的位置。
```

图解：

```text
body_top_left
    x
    |
    |  - spriteSourceSize.y
    v
draw_pos +-------------------+
         | trimmed sprite    |
         +-------------------+
```

这个模型的问题是：

```text
body_top_left 是碰撞/逻辑盒子的概念，
spriteSourceSize 是 Aseprite 原始帧里的概念。
```

两者不一定天然对齐。除非 `animation.anchorOffset` 被调过，否则人物可能会
贴着 body 左上角附近出现。


### 模型 B：以 source frame 固定锚点为基准

更清晰的模型是：

```odin
source_anchor := animation.anchorOffset
source_frame_to_sprite := V2i{frame.spriteSourceSize.x, frame.spriteSourceSize.y}

draw_pos =
    anchor_buffer_pos +
    source_frame_to_sprite -
    source_anchor
```

含义：

```text
把原始 source frame 里的固定 source_anchor 对齐到 entity anchor，
再根据 spriteSourceSize.xy 找到当前 trimmed sprite 的左上角。
```

图解：

```text
原始 source frame 内部

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
|             source_anchor      |
|                                |
+--------------------------------+

trimmed sprite 左上角 = spriteSourceSize.xy
source_anchor = 美术/代码约定的固定角色锚点，比如 V2i{101, 137}
```

画到 buffer 时：

```text
buffer

anchor_buffer_pos
        x
        ^
        |
让 source_anchor 对齐到这里

draw_pos = anchor_buffer_pos + spriteSourceSize.xy - source_anchor
```

这个模型把概念分开了：

```text
entity anchor 负责世界/屏幕位置
source_anchor 负责素材原始 frame 内部的固定角色锚点
spriteSourceSize 负责 trim 还原
frame 负责 atlas 裁图
```


## 当前问题怎么判断

如果 debug 结果是：

```text
白色十字在中央
蓝框正确
红框中人物动画正确
红框位置不对
```

那就不要再改这些地方：

```text
relative_pos
rel_pos_to_buffer_pos
entity_top_left_from_anchor
frame / atlas_offset
draw_image_corp
```

应该改的是：

```text
draw_entity_animation 里 draw_pos 的计算公式
```

尤其是要决定：

```text
动画到底以 body_top_left 为基准？
还是以 anchor_buffer_pos 为基准？
```

目前从调试结果看，`anchor_buffer_pos` 和 body box 都是正确的，所以动画更适合
改成“以 entity anchor 为基准”的模型。

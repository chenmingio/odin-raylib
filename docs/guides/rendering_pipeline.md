# 渲染流水线

| 字段 | 内容 |
|---|---|
| Status | Draft（框架） |
| Code scope | `main.odin`、`game/render*.odin`、`game/animation.odin` |
| Last verified | TODO |

> 本文解释上层数据流和坐标变换；像素裁剪、atlas trim 和动画 anchor 的细节放在[图片与动画](draw_image_animation.md)。

## 要解决的问题

<!-- TODO: 为什么项目使用 CPU framebuffer？它给学习、调试和可控性带来什么，又失去什么？ -->

## 从世界到屏幕的总流程

```text
WorldPosition
  -> position relative to camera
  -> SimEntity.p
  -> buffer pixel anchor
  -> destination rectangle
  + atlas source rectangle
  -> clipped/blended CPU pixels
  -> Raylib texture upload
  -> window framebuffer
```

<!-- TODO: 标出每一步对应函数和数据单位。 -->

## CPU framebuffer 与 Raylib 的职责边界

| 工作 | 项目软件渲染器 | Raylib |
|---|---|---|
| Window / texture / present | TODO | TODO |
| Rectangle / image pixels | TODO | TODO |
| Clipping / blend / rotate | TODO | TODO |

### 为什么不直接使用 Raylib DrawTexture

<!-- TODO: Current decision、学习目的、性能和功能代价。 -->

### 像素格式与颜色

<!-- TODO: u32 布局、byte_swap、alpha 约定和 image 数据格式。 -->

## 四套坐标

| 坐标空间 | 单位 | 原点 | 轴方向 | 示例类型 |
|---|---|---|---|---|
| World | meter + chunk | TODO | TODO | `WorldPosition` |
| Sim relative | meter | camera | TODO | `V3` / `SimEntity.p` |
| Buffer destination | pixel | TODO | TODO | `V2i` |
| Atlas source | pixel | image top-left | TODO | `AseRect` / `TileMapRect` |

### World 到 camera-relative

<!-- TODO: relative_pos 的精度收益。 -->

### Relative 到 buffer

<!-- TODO: X、Y、Z 的公式；为什么 Y 翻转，为什么 Z 投影到 screen Y。 -->

### Meter 到 pixel

<!-- TODO: PIXELS_PER_METER、整数截断和缩放策略。 -->

## Anchor 与 Box 不应混为一谈

| 概念 | 表示什么 | 使用位置 |
|---|---|---|
| Entity anchor / ground point | TODO | TODO |
| Collision body box | TODO | TODO |
| Source-frame anchor | TODO | TODO |
| Trim offset | TODO | TODO |
| Rotation anchor | TODO | TODO |

<!-- TODO: 用同一个 Player frame 画一张或一段 ASCII 图说明五者关系。 -->

## 一帧中的绘制顺序

1. TODO: clear software buffer
2. TODO: debug/world background
3. TODO: visible terrain chunks
4. TODO: SimRegion entities
5. TODO: collision/debug overlay
6. TODO: upload and present

### Terrain 与 Entity 的顺序

<!-- TODO: 当前先后顺序的结果。 -->

### Entity depth ordering

<!-- TODO: 当前遍历顺序是否稳定、为什么不是可靠的 painter's algorithm、未来选项。 -->

| 方案 | 优点 | 代价 |
|---|---|---|
| 当前 SimRegion 顺序 | TODO | TODO |
| 按 screen/world Y 排序 | TODO | TODO |
| render command buffer | TODO | TODO |

## 渲染路径分类

### Primitive rectangle

<!-- TODO: draw_rectangle、debug 与 hit point。 -->

### Static image

<!-- TODO: draw_image_simple / draw_entity_image。 -->

### Animated sprite

<!-- TODO: animation clip/frame 到 source rect 和 anchor。 -->

### Rotated sprite

<!-- TODO: harpoon 使用 velocity 推导方向的路径。 -->

### Terrain tile

<!-- TODO: tile visual 到 atlas rect 和 world position。 -->

## Clipping、Flipping、Rotation 与 Blending

<!-- TODO: 说明各变换发生的顺序；顺序交换会造成什么区别。 -->

## 关键不变量

- [ ] source rect 在 atlas 范围内。
- [ ] destination clipping 后不会访问 framebuffer 越界。
- [ ] entity ground anchor 与 collision/render debug 使用同一语义。
- [ ] reverse/rotation 后 anchor 仍落在预期 buffer 点。
- [ ] TODO: alpha 与像素格式不变量。

## 当前限制

- **Known limitation**：TODO: depth sorting。
- **Known limitation**：TODO: 每帧整张 texture upload 的成本。
- **Known limitation**：TODO: integer rounding、camera jitter 或 high-DPI 行为。

## 如何验证

| 风险 | 验证方式 | 当前状态 |
|---|---|---|
| Anchor 漂移 | 固定 anchor overlay | TODO |
| Atlas clipping 越界 | assert + edge-case image | TODO |
| Reverse/rotation 错位 | 可视化矩阵测试 | TODO |
| Draw order 错误 | overlap scene | TODO |
| CPU render 成本 | profiling | TODO |

## 代码入口

- `main.odin` — framebuffer 创建、texture upload 和 present
- `game/render.odin` — 坐标转换和 render orchestration
- `game/render_bitmap.odin` — 像素级 primitive/image 操作
- `game/render_entity.odin` — entity、animation、sprite
- `game/render_terrain.odin` — terrain tile
- `game/render_debug.odin` — debug overlay
- `game/animation.odin` — Aseprite metadata

## 相关文档

- [总体架构](architecture_overview.md)
- [图片与动画](draw_image_animation.md)
- [Terrain 架构](terrain_architecture.md)
- [World Position](world_position.md)
- [SimRegion](sim_region.md)

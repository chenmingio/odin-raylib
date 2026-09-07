# Terrain 架构

| 字段 | 内容 |
|---|---|
| Status | Draft（框架） |
| Code scope | `game/terrain.odin`、`game/terrain_layout.odin`、`game/render_terrain.odin`、`game/world.odin` |
| Last verified | TODO；当前 Terrain 相关代码仍在演进 |

> 本文框架刻意把“素材描述”“逻辑地形”“空间存储”“视觉绘制”和“可行走性”分开。填写时不要因为它们目前共享字段或坐标就默认属于同一层。

## 要解决的问题

<!-- TODO: 为什么地图不能只是一张背景图？为什么 terrain tile 和 entity 需要并存？ -->

## 概念分层

| 层 | 核心类型 | 负责的问题 |
|---|---|---|
| 素材元数据 | `TileMapSheet`、`TileMapSlice` | TODO |
| 渲染素材 | `TileMapAsset`、`Tile`、`TileVisual` | TODO |
| 逻辑地形 | `TerrainTile`、`TileArea` | TODO |
| 空间存储 | `WorldChunk.tile_map` | TODO |
| 特殊空间对象 | `LowEntity` of type `Stair` | TODO |
| 绘制 | `draw_chunk_tile_map`、`draw_tile` | TODO |

## 素材数据契约

<!-- TODO: Aseprite JSON slice name 如何映射到 TileVisual enum。 -->

必须说明：

- enum 名称与素材 slice 名称的耦合；
- 为什么每种非 Empty visual 必须存在；
- 重复 slice、空 keys、atlas 越界如何失败；
- 这个严格契约的好处和素材迭代成本；
- soft-code metadata 与 hard-coded enum 的替代方案。

## Tile 坐标、Chunk 坐标与负数

```text
world tile coordinate
  -> tile_axis_to_chunk
  -> chunk coordinate + local tile coordinate
  -> WorldChunk.tile_map[local_y][local_x]
```

<!-- TODO: 用正数、边界和负数各举一个例子，解释 `%%` 的选择。 -->

### 关键不变量

- [ ] local x/y 始终落在 `CHUNK_TILE_DIM` 范围内。
- [ ] 同一个 world tile coordinate 始终映射到唯一 chunk/local pair。
- [ ] 逻辑坐标约定与 WorldPosition 的 chunk 原点约定一致。

## TerrainTile 为什么同时保存 visual 和 level

<!-- TODO: 哪个是渲染选择，哪个是游戏语义？level 当前在哪些路径真正被读取？ -->

## Area 到具体 TileVisual 的规则

### Flat ground

<!-- TODO: isolated、edge、corner、narrow 的决策树。 -->

### Elevated surface

<!-- TODO: surface 和 cliff-top 的关系。 -->

### Cliff face

<!-- TODO: face 为什么是额外写入的 tile，如何避免覆盖其他内容。 -->

### 为什么当前使用规则函数而不是邻居 autotiling

| 方案 | 优点 | 代价 | 适用阶段 |
|---|---|---|---|
| 从 TileArea 生成 visual | TODO | TODO | 当前 |
| 根据邻居实时 autotile | TODO | TODO | TODO |
| 离线地图工具导出最终 visual | TODO | TODO | TODO |

## Stair 为什么是 Entity

<!-- TODO: 与普通 TerrainTile 对比生命周期、碰撞、方向、查询和渲染。 -->

需要回答：

- Stair 的方向和 level 为什么不只存在 tile_map 中？
- Stair 是否应该同时写一个 terrain visual？
- `traversable`、World Z、tile level 分别承担什么语义？
- 未来多个 collision volume 或 ground entity 会不会改变这个划分？

## 生成与加载时序

1. TODO: World 初始化
2. TODO: demo terrain 写入 chunk
3. TODO: tilemap asset 加载
4. TODO: visible chunk 查询
5. TODO: terrain render

<!-- TODO: 注意核对 asset 加载与 demo terrain 创建的实际先后关系及其后果。 -->

## 渲染位置与逻辑高度

<!-- TODO: tile 的世界左下角、屏幕左上角、level、Z 投影之间的当前关系。 -->

## 当前限制

- **Known limitation**：TODO: level、stair、traversable 尚未闭环的部分。
- **Known limitation**：TODO: chunk 只在 z=0 存 tile_map 是否是有意约束。
- **Known limitation**：TODO: tile 覆盖、空 tile 和地图编辑策略。

## 如何验证

| 场景 | 验证方式 | 当前状态 |
|---|---|---|
| 负 tile 坐标跨 chunk | unit test | TODO |
| 1x1、1xN、Nx1、NxM visual 选择 | table test | TODO |
| atlas metadata 完整性 | loader assert/test | TODO |
| level 与 stair 的视觉/碰撞对齐 | debug overlay | TODO |

## 代码入口

- `game/terrain.odin` — 类型、asset 加载、visual 选择和 tile 写入
- `game/terrain_layout.odin` — 当前 demo 地图描述
- `game/render_terrain.odin` — terrain 绘制
- `game/world.odin` — chunk 内 tile_map 存储

## 相关文档

- [World Position](world_position.md)
- [WorldChunk](world_chunk.md)
- [渲染流水线](rendering_pipeline.md)
- [Entity](entity.md)
- [Day 070–080 计划](handmade_hero_day_070_080_plan.md)

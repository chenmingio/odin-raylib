# Guides 文档地图

这里记录项目的架构、设计取舍和实现专题。项目根目录的 `README.md` 负责构建与运行，本目录负责解释系统如何工作以及为什么这样设计。

> 当前状态：文档正在系统整理。标为“框架”的文章只有待填写提纲，不代表其中列出的设计已经实现；标为“待复核”的文章可能与当前代码存在偏差。

## 如何阅读

第一次了解项目，建议按这条主线阅读：

1. [总体架构](architecture_overview.md)
2. [游戏内存](game_memory.md)
3. [Entity](entity.md)
4. [World Position](world_position.md)
5. [WorldChunk](world_chunk.md)
6. [SimRegion](sim_region.md)
7. [碰撞系统](collision.md)
8. [Terrain 架构](terrain_architecture.md)
9. [渲染流水线](rendering_pipeline.md)
10. [图片与动画](draw_image_animation.md)
11. [平台能力](#平台能力)
12. [测试策略](testing.md)

## 文档状态

| 状态 | 含义 |
|---|---|
| 框架 | 已创建问题清单和章节结构，正文待填写 |
| 待复核 | 已有内容，但尚未按当前代码完整核对 |
| 专题 | 集中解释一个局部主题，不承担总体架构说明 |
| 计划 | 记录未来工作，不描述当前实现 |
| 归档 | 保留历史学习材料，不作为当前代码依据 |

文章中的设计主张应进一步区分 `Current`、`Target`、`Alternative`、`Historical` 和 `Known limitation`。详细约定见[文档查缺补漏计划](documentation_plan.md#文档状态约定)。

## 核心运行时

| 主题 | 文档 | 状态 | 主要代码 |
|---|---|---|---|
| 平台与游戏层、一帧生命周期 | [总体架构](architecture_overview.md) | 框架 | `main.odin`、`game/game.odin`、`game/game_init.odin` |
| 数据所有权和容器选择 | [容器设计](container_design.md) | 待复核 | `game/game.odin`、`game/entity.odin`、`game/world.odin` |
| 数据生命周期 | [数据生命周期](data_lifetime.md) | 待复核 | `main.odin`、`game/game.odin` |
| Arena 与 GameState | [游戏内存](game_memory.md) | 待复核 | `main.odin`、`game/game.odin` |
| Entity 长期状态 | [Entity](entity.md) | 待复核 | `game/entity.odin`、`game/entity_location.odin` |
| 单帧模拟工作集 | [SimRegion](sim_region.md) | 待复核 | `game/sim_region.odin` |
| Player、Shark、Weapon 状态 | [Actor 状态](actor_state.md) | 框架 | `game/player.odin`、`game/shark.odin` |

## 世界与空间

| 主题 | 文档 | 状态 | 主要代码 |
|---|---|---|---|
| 大世界坐标和 canonicalization | [World Position](world_position.md) | 待复核 | `game/world.odin` |
| Chunk 空间索引 | [WorldChunk](world_chunk.md) | 待复核 | `game/world.odin`、`game/entity_location.odin` |
| Storage 与 index 的分离 | [储存与索引](store_vs_index.md) | 待复核 | `game/entity.odin`、`game/world.odin` |
| Terrain 数据、素材和层级 | [Terrain 架构](terrain_architecture.md) | 框架 | `game/terrain.odin`、`game/terrain_layout.odin` |

## 模拟与碰撞

| 主题 | 文档 | 状态 | 主要代码 |
|---|---|---|---|
| Swept AABB 与碰撞响应 | [碰撞系统](collision.md) | 待复核 | `game/collision.odin`、`game/sim_region.odin` |
| Entity pair 的碰撞策略 | [碰撞规则](collision_rules.md) | 框架 | `game/collision_rules.odin` |
| Day 070–080 学习路线 | [学习与移植计划](handmade_hero_day_070_080_plan.md) | 计划 | 多个 world/sim/collision 模块 |

## 渲染与素材

| 主题 | 文档 | 状态 | 主要代码 |
|---|---|---|---|
| 从世界到 framebuffer | [渲染流水线](rendering_pipeline.md) | 框架 | `game/render*.odin`、`main.odin` |
| Atlas、trim、anchor 与动画 | [图片与动画](draw_image_animation.md) | 专题 | `game/animation.odin`、`game/render_bitmap.odin`、`game/render_entity.odin` |

## 平台能力

| 主题 | 文档 | 状态 | 主要代码 |
|---|---|---|---|
| 输入抽象 | [平台输入](platform_input.md) | 框架 | `platform/input.odin`、`game/controller.odin` |
| 动态库与热重载 | [动态库](dynamic_lib.md) | 待复核 | `platform/load_game.odin` |
| 输入录制与回放 | [录制回放](plateform_record.md) | 待复核；待重命名 | `platform/record.odin` |
| 音频 callback 与 ring buffer | [平台音频](platform_audio.md) | 待复核 | `platform/audio.odin` |

## 工程方法和补充材料

| 主题 | 文档 | 状态 |
|---|---|---|
| 测试、assert、overlay、replay | [测试策略](testing.md) | 计划为主；仓库当前没有正式测试 |
| 数据结构概览 | [数据结构选择](data_structure.md) | 待整理 |
| 单链表基础 | [单链表](single_chain.md) | 待整理 |
| 文档治理 | [文档查缺补漏计划](documentation_plan.md) | 计划 |
| 新文章起稿 | [Guide 写作模板](guide_template.md) | 模板 |

## 按代码反查文档

| 代码 | 首选文档 |
|---|---|
| `main.odin` | [总体架构](architecture_overview.md)、[游戏内存](game_memory.md)、[渲染流水线](rendering_pipeline.md) |
| `platform/input.odin`、`game/controller.odin` | [平台输入](platform_input.md) |
| `platform/load_game.odin` | [动态库](dynamic_lib.md) |
| `platform/record.odin` | [录制回放](plateform_record.md) |
| `platform/audio.odin` | [平台音频](platform_audio.md) |
| `game/game.odin`、`game/game_init.odin` | [总体架构](architecture_overview.md)、[游戏内存](game_memory.md) |
| `game/entity.odin`、`game/entity_location.odin` | [Entity](entity.md)、[WorldChunk](world_chunk.md) |
| `game/world.odin` | [World Position](world_position.md)、[WorldChunk](world_chunk.md) |
| `game/sim_region.odin` | [SimRegion](sim_region.md)、[碰撞系统](collision.md) |
| `game/collision.odin` | [碰撞系统](collision.md) |
| `game/collision_rules.odin` | [碰撞规则](collision_rules.md) |
| `game/player.odin`、`game/shark.odin` | [Actor 状态](actor_state.md) |
| `game/terrain*.odin`、`game/render_terrain.odin` | [Terrain 架构](terrain_architecture.md)、[渲染流水线](rendering_pipeline.md) |
| `game/animation.odin`、`game/render*.odin` | [渲染流水线](rendering_pipeline.md)、[图片与动画](draw_image_animation.md) |

## 维护规则

- 先描述当前代码，再讨论目标方案和历史参考。
- 修改核心 struct、生命周期或一帧时序时，同步检查对应 guide。
- 代码示例如果是伪代码，必须明确标注，不能使用看起来像当前实现的旧名称。
- 性能结论需要 benchmark 或可核对来源；否则只写定性取舍。
- 完成一篇文章前，使用[写作模板](guide_template.md#完成检查)进行检查。

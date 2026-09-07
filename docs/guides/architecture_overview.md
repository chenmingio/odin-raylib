# 总体架构与一帧生命周期

| 字段 | 内容 |
|---|---|
| Status | Draft（框架） |
| Code scope | `main.odin`、`platform/*.odin`、`game/game.odin`、`game/game_init.odin` |
| Last verified | TODO |

> 本文只建立待填写框架。填写时应以当前调用顺序为主线，再链接到各专题文档。

## 这套架构要解决什么问题

<!-- TODO: 项目为什么区分 platform 与 game？为什么需要固定内存、动态库和软件 framebuffer？ -->

需要回答：

- 如果所有代码都编译进一个 executable，会失去什么开发体验？
- 为什么游戏状态必须独立于可重载的游戏代码？
- Raylib 在这里承担哪些平台能力，哪些能力由项目自己实现？

## Platform 与 Game 的边界

<!-- TODO: 解释 executable、shared library、导出函数和共享类型。 -->

| 层 | 负责什么 | 不负责什么 | 生命周期 |
|---|---|---|---|
| Platform | TODO | TODO | 进程级 |
| Game | TODO | TODO | 可重载代码 |

```text
main executable
  -> platform input / audio / record / dylib loader
  -> exported game procedures
  -> persistent game memory
```

### 跨边界的数据和 ABI

<!-- TODO: Memory、Input、OffScreenBuffer、SoundOutputBuffer 和 proc type。 -->

### 边界选择的收益与代价

<!-- TODO: 热重载速度、平台隔离、ABI 风险、调试复杂度。 -->

## 长期对象关系

<!-- TODO: 标出 value、pointer、index 和临时投影。 -->

```text
Memory
  -> permanent storage
       -> GameState
            -> World
            -> LowEntity storage
            -> assets
  -> temporary storage

World spatial index
  -> entity storage index
       -> LowEntity

SimRegion
  -> SimEntity
       -> LowEntity
```

### 谁是 source of truth

<!-- TODO: GameState、LowEntity、WorldChunk index、SimEntity.p 分别是什么角色？ -->

### 生命周期总表

| 数据 | 创建时机 | 失效时机 | 内存来源 |
|---|---|---|---|
| Platform state | TODO | TODO | TODO |
| GameState | TODO | TODO | TODO |
| World/LowEntity/assets | TODO | TODO | TODO |
| SimRegion | TODO | TODO | TODO |
| framebuffer | TODO | TODO | TODO |

## 启动流程

<!-- TODO: 严格按 main.odin 的真实顺序填写。 -->

1. TODO: window / display
2. TODO: audio
3. TODO: framebuffer / texture
4. TODO: input
5. TODO: game code
6. TODO: storage / arena
7. TODO: first game initialization

需要解释：为什么 `GameState` 的初始化发生在 game export 内，而 storage 和 allocator 在 platform 创建？

## 一帧的真实执行顺序

```text
window loop
  -> record/replay mode transition
  -> real or replayed Input
  -> hot reload check
  -> pause handling
  -> game update_and_render
       -> initialize if needed
       -> update player and shark state
       -> update camera
       -> begin_sim
       -> simulate
       -> render terrain and entities
       -> end_sim and reindex
  -> upload CPU buffer to texture
  -> present frame
```

<!-- TODO: 逐项核对上述骨架；不准确时以代码为准修改。 -->

### 为什么 actor update 在 begin_sim 之前

<!-- TODO: 当前收益、直接修改 LowEntity 的含义、改成统一 sim update 的备选。 -->

### 为什么 render 在 end_sim 之前

<!-- TODO: render 使用 SimEntity.p；end_sim 如何把相对位置变回 WorldPosition。 -->

### Camera 更新时机

<!-- TODO: camera 使用模拟前还是模拟后的位置？这会产生一帧延迟或其他行为吗？ -->

## 时间模型

<!-- TODO: TARGET_UPDATE_HZ、FIXED_DT、SetTargetFPS、真实 wall-clock time。 -->

必须区分：

- 固定 simulation dt；
- Raylib 的帧率限制；
- 动画和 projectile timer 的单位；
- hot reload 的“每 N 帧检查”与真实秒数；
- 暂停时哪些系统仍运行。

## Hot Reload、Replay 与确定性

<!-- TODO: 这里只讲三者关系，细节链接到专题。 -->

```text
stable memory layout
  -> hot reload preserves state
  -> replay restores state bytes
  -> deterministic update makes the same input useful
```

需要回答：

- 哪些状态在 snapshot 内，哪些在外？
- 哪些指针或资源句柄不能跨进程恢复？
- 修改跨 DLL 类型布局会怎样？

## 关键不变量

- [ ] Game 与 Platform 对跨边界类型布局的理解一致。
- [ ] `GameState` 在初始化后始终位于预期 storage 地址。
- [ ] 一帧内的 SimEntity 引用不会跨帧保存。
- [ ] spatial entity 的 WorldPosition 与 chunk index 一致。
- [ ] TODO: 补齐 framebuffer、input、audio 不变量。

## 当前限制与演进方向

<!-- TODO: 每项标 Current limitation 或 Target。 -->

- **Known limitation**：TODO
- **Target**：TODO

## 如何验证

| 行为 | 验证方式 | 当前状态 |
|---|---|---|
| DLL 加载失败时的行为 | 手动/集成测试 | TODO |
| 固定输入产生一致状态 | replay + 状态 hash | TODO |
| entity 跨 chunk 后索引一致 | assert / test / overlay | TODO |
| render anchor 和 collision 对齐 | debug overlay | TODO |

## 代码入口

- `main.odin` — platform 初始化和主循环
- `game/game.odin` — game ABI、GameState 和每帧入口
- `game/game_init.odin` — 首次初始化
- `platform/load_game.odin` — 动态库边界
- `platform/record.odin` — snapshot 与输入流

## 相关文档

- [游戏内存](game_memory.md)
- [Entity](entity.md)
- [WorldChunk](world_chunk.md)
- [SimRegion](sim_region.md)
- [渲染流水线](rendering_pipeline.md)
- [动态库](dynamic_lib.md)
- [录制回放](plateform_record.md)
- [平台输入](platform_input.md)

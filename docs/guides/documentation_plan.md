# 项目文档查缺补漏计划

## 目标

把 `docs/guides` 从零散的学习笔记整理成一套能够回答以下问题的项目文档：

1. 项目每一帧如何运行，各模块如何协作？
2. 数据由谁拥有、存在哪里、存多久、什么时候改变？
3. 当前设计为什么这样选，牺牲了什么？
4. 哪些内容已经实现，哪些只是目标、备选方案或历史背景？
5. 设计在哪些条件下会失效，届时应该换成什么？
6. 如何通过测试、assert、可视化或 replay 验证文档中的结论？

这份计划只规划文档工作，不要求为了让文档“显得完整”而提前修改代码。遇到文档与代码不一致时，先明确记录现状和目标，再单独决定修改哪一边。

## 文档状态约定

每篇架构或设计文档开头都应标明：

| 字段 | 含义 |
|---|---|
| `Status` | `Draft`、`Current` 或 `Historical` |
| `Code scope` | 对应的主要代码文件 |
| `Last verified` | 最后一次按代码核对的日期和 commit |

正文中的重要设计主张使用以下标签区分：

| 标签 | 含义 |
|---|---|
| **Current** | 当前代码已经如此运行 |
| **Target** | 希望实现、但尚未实现的设计 |
| **Alternative** | 讨论过但当前未采用的方案 |
| **Historical** | Handmade Hero、旧版本或其他参考实现 |
| **Known limitation** | 当前已知并暂时接受的限制 |

最重要的规则是：不能把 `Target` 或 `Historical` 写成当前代码已经具备的能力。

## 单篇文档的完成标准

一篇设计文档至少应回答以下八项；如果某项不适用，应明确说明原因。

1. **问题**：这个模块解决什么问题，为什么需要单独存在？
2. **所有权**：权威数据在哪里，谁可以修改，其他结构保存副本、指针还是索引？
3. **生命周期**：数据何时创建、何时失效、由哪个 allocator 或容器提供内存？
4. **时序**：它在一帧、一次加载或一次状态转换中的调用顺序是什么？
5. **选择理由**：当前方案优化了什么，又牺牲了什么？
6. **替代方案**：考虑过哪些方案，为什么暂时不用，什么条件下应该切换？
7. **边界和失败模式**：容量、浮点、顺序、并发、引用失效等假设是什么？
8. **验证方式**：对应哪些测试、assert、debug overlay、replay 或 profiling 指标？

此外，每篇文档应包含：

- 指向当前代码入口的链接或文件名；
- 至少一个端到端流程，而不只是数据结构字段说明；
- 明确的不变量清单；
- “当前没有解决什么”一节；
- 与相关 guide 的交叉链接。

## 当前覆盖情况

| 主题 | 当前材料 | 主要问题 | 动作 |
|---|---|---|---|
| 总体架构和帧流水线 | `README.md`、`CLAUDE.md` | 只有目录级概述，没有串起调用顺序和数据流 | 新增 |
| Entity | `entity.md` | 内容过短；没有讲引用、删除、复用和权威状态 | 重写 |
| SimRegion | `sim_region.md` | 更像问题草稿；没有准确描述当前混合模型 | 重写 |
| WorldPosition | `world_position.md` | 整体较完整 | 核对并小修 |
| WorldChunk | `world_chunk.md`、`container_design.md` | 设计讨论较丰富，但字段、参数和部分结论已过期 | 优先修订 |
| Collision | `collision.md` | 理论较深入，但部分内容是目标方案，不是当前实现 | 优先修订 |
| Collision rules | 零散代码注释 | 缺少规则生命周期及 entity ID 复用风险 | 新增或并入碰撞文档 |
| 内存和数据生命周期 | `game_memory.md`、`data_lifetime.md` | 与当前 GameState 放置方式、temporary arena 行为不一致 | 重写 |
| 热重载 | `dynamic_lib.md` | 只讲基本机制，缺 ABI、失败恢复和状态兼容性 | 扩写 |
| 录制与回放 | `plateform_record.md` | 缺确定性、指针和 allocator 状态约束；文件名拼写错误 | 重命名并重写 |
| 音频 | `platform_audio.md` | 原理笔记为主；没有区分已启用路径和未完成设计 | 扩写 |
| 输入 | 无独立文档 | 模块较小，但它是 replay 和状态机的边界 | 后补或并入主循环 |
| 软件渲染 | `draw_image_animation.md` | 像素和动画细节充分，但缺上层渲染流水线 | 新增概览 |
| Terrain | 无 | 已成为跨 world、asset、render、entity 的重要模块 | 新增 |
| Actor/玩法状态机 | 无 | Player、Shark、Weapon 的更新顺序和职责不清楚 | 新增或并入 Entity |
| 测试和调试 | `testing.md`、debug draw 代码 | 文档是建议方案，仓库当前没有正式测试和 `validate_world` | 标明 Target 并逐步落地 |
| 数据结构通识 | `data_structure.md`、`store_vs_index.md` | 通用知识较多，与本项目事实混杂且有重复 | 最后整理 |

## 实施顺序

### 阶段 1：建立阅读入口和事实边界

#### 1.1 新增 `docs/guides/README.md`

目标：让读者知道应该按什么顺序阅读，也让维护者看到覆盖缺口。

建议结构：

1. 项目概览；
2. 推荐阅读路径；
3. guide 覆盖矩阵；
4. `Current` / `Target` / `Historical` 状态说明；
5. 按代码模块反查文档的索引。

验收标准：

- `game/` 和 `platform/` 下的每个主要模块都能找到对应 guide，或明确标为“尚未覆盖”；
- 读者可以从总体架构逐步进入 world、simulation、render 和 platform；
- 不再只能依赖文件名猜测阅读顺序。

#### 1.2 新增 `architecture_overview.md`

目标：先建立全局心智模型，再进入局部算法。

必须覆盖：

- platform executable 与 game dynamic library 的边界；
- `Memory`、`GameState`、`World`、`LowEntity`、`SimRegion` 的所有权关系；
- 一帧的实际调用顺序：

  ```text
  platform input
      -> actor state update
      -> camera update
      -> begin_sim
      -> simulate / collision
      -> terrain + entity render
      -> end_sim / spatial reindex
      -> upload framebuffer
  ```

- 为什么 player/shark 逻辑在 `begin_sim` 之前直接修改 `LowEntity`；
- 固定 dt、目标帧率、pause、hot reload 和 replay 在循环中的位置；
- 当前顺序带来的可见行为和限制。

验收标准：读者读完后能说清“输入如何最终改变屏幕上的一个像素”和“一个 entity 如何跨 chunk 移动”。

### 阶段 2：修正基础数据模型

#### 2.1 重写 `entity.md`

必须覆盖：

- `LowEntity` 为什么是长期权威状态；
- 固定数组、storage index 和 free-index list 的关系；
- `0` 是否有保留语义，当前代码如何处理；
- `owner`、`weapon` 等跨 entity 引用为什么存 index；
- `non_spatial`、`moveable`、`collides`、`updatable` 的区别；
- 删除当前只是把 index 加入 free list，尚未形成完整销毁协议；
- index 被复用时旧引用可能指向新 entity，何时需要 generational handle；
- entity 字段混合 render、physics、gameplay 数据的便利与代价。

需要写出的不变量：

- 有效 index 必须落在固定数组范围内；
- spatial entity 必须且只能出现在其 `pos.chunkXYZ` 对应的 chunk index 中；
- non-spatial entity 不应出现在 chunk index；
- index 回收前必须清理空间索引、collision rule 和外部引用。

#### 2.2 重写 `sim_region.md`

必须准确描述当前混合模型：

```text
LowEntity                 长期权威状态
    ^
SimEntity.low_entity      直接访问大多数长期字段
SimEntity.p               单帧相对坐标副本
```

必须覆盖：

- 为什么只模拟 camera 附近，而不是所有 entity；
- simulation bounds 和 updatable bounds 为什么不同；
- `max_entity_radius + max_entity_velocity * dt` margin 的来源和保守性；
- begin/simulate/render/end 的生命周期；
- 为什么使用 camera-relative float 坐标；
- 当前按 entity 顺序更新，结果可能依赖遍历顺序；
- SimEntity 没有 `storage_index -> SimEntity` 映射带来的线性查找和引用解析问题；
- 完整复制 LowEntity 与当前指针模型的两种取舍；
- 4096 固定容量、栈占用和溢出策略。

#### 2.3 修订 `world_chunk.md` 和 `container_design.md`

先按当前代码纠正：

- `low_entities`、`entities`、`SimEntity` 等现用命名；
- `CHUNK_TILE_DIM = 10 x 10`、`CHUNK_HEIGHT_METERS = 10`；
- `chunk_dim_in_meters` 是 `V3`；
- `first_free_entity_block` 等真实字段名；
- block 满时新 block 是头插，不是尾插；
- hash 函数自身已经执行 `% 4096`；
- 16 个 u32 的 payload 是 64 字节，但整个节点不止一个 cache line，也不能假定天然按 cache line 对齐；
- 固定数组中的 entity 不会因为跨 chunk 移动而改变地址；
- `get_world_chunk(..., memory)` 在查询缺失 chunk 时会创建永久节点。

需要重新评估而不是直接保留的结论：

- Odin `map` 扩容是“不够可控/可能持续消耗 arena”，不等于必然“破坏 arena 内存布局”；
- spatial hash 的查询、移动只是平均复杂度接近 O(1)，仍取决于 bucket 冲突和涉及的 chunk 数量；
- generation 是否必要取决于所有外部引用，而不只是 chunk 是否中心化维护；
- “相比普通链表快约 100 倍”如果没有本项目 benchmark 或可核对来源，应删除或明确标为外部历史结果。

### 阶段 3：把内存、热重载和 Replay 作为一个整体说明

#### 3.1 重写 `game_memory.md` 和 `data_lifetime.md`

必须覆盖：

- 一块连续 storage 如何切成 permanent 和 temporary；
- `GameState` 为什么直接放在 permanent storage 开头；
- permanent arena 为什么从 `size_of(GameState)` 之后开始；
- Arena 元数据位于 platform 栈上，而实际字节位于 storage 中；
- 当前 `temporary_arena` 没有每帧 reset，不能写成“当前每帧批量释放”；
- asset image 使用 permanent allocator，JSON/parser 临时数据使用 temp allocator；
- permanent、frame、level、asset arena 是通用设计选项，不都是当前实现；
- alignment、容量耗尽、热重载后结构布局变化等失败模式。

#### 3.2 扩写 `dynamic_lib.md`

必须覆盖：

- platform/game ABI 中的函数签名和 export symbol；
- stub 的作用；
- 当前基于 dylib 修改时间的检测方式；
- 为什么代码可以重载而 GameState 保持不变；
- `GameState` 或跨边界 struct 布局变化的兼容风险；
- 直接加载正在写入的 dylib、先卸载旧库再加载新库的失败窗口；
- 临时文件复制、lock file、保留旧库直到新库验证成功等替代方案；
- 函数指针、类型布局、allocator 和资源句柄跨重载的边界。

#### 3.3 将 `plateform_record.md` 重命名为 `platform_record.md` 并重写

必须覆盖：

- 文件真实布局是 memory snapshot 后跟逐帧 Input；
- input stream 不在 game memory 内；
- 为什么 storage 必须连续；
- 回放到 EOF 时如何恢复 snapshot 并循环；
- 同一进程内恢复与跨进程存档不是一回事；
- raw pointer、地址稳定、外部资源、文件句柄不能只靠字节快照恢复；
- Arena 元数据没有包含在 snapshot 中；
- 随机数、固定 dt、更新顺序和非确定性输入对 replay 的影响；
- 文件版本、短读短写、损坏文件等尚未处理的问题。

最后补一篇短文或章节，把三者串起来：

```text
persistent memory layout
    -> hot reload keeps state
    -> replay snapshots state
    -> both depend on stable ABI/address/lifetime assumptions
```

### 阶段 4：修正 simulation 和 collision 的“实现/目标”混淆

#### 4.1 修订 `collision.md`

保留已有 Minkowski、swept AABB 和接触误差讨论，但逐节标注当前状态。

必须明确：

- 当前仅在 XY 平面做 swept AABB，Z 位移单独积分；
- `surface` 当前表达切线方向，而不是文档公式中的法线；
- 代码当前仍使用 `sweep_fraction - 0.001`；“保持精确 fraction”是 Target；
- 初始重叠、固定 world-space skin、角点双法线是设计建议，尚未完整实现；
- 当前不是全局最早事件求解器，而是按 entity 顺序、每个 entity 最多四次迭代；
- 其他 moveable entity 在检测时可能已经被本帧较早的 entity 更新，结果依赖顺序；
- collision geometry、collision policy 和 gameplay event 应分层解释。

#### 4.2 增加 Collision Rule 章节或独立文档

必须覆盖：

- general rule 与 pairwise override 的优先级；
- entity pair 为什么先排序再 hash；
- rule hash chain 和 free list 的所有权；
- weapon-owner、weapon-player 的实际生命周期；
- 为什么 projectile 回收时要清除相关 rule；
- entity index 复用但旧 rule 未清理时的风险；
- non-stopping collision 当前会直接采用完整剩余位移，可能跳过路径上后续障碍物。

### 阶段 5：补齐 Terrain 和 Rendering

#### 5.1 新增 `terrain_architecture.md`

必须覆盖：

- `TileVisual`、Aseprite slice name 和 JSON enum 解析之间的数据契约；
- tile world coordinate 到 chunk/local coordinate 的转换，特别是负坐标的 `%%`；
- `TerrainTile` 为什么存在 `visual` 和 `level`；
- surface、edge、corner、cliff face 的选择规则；
- tile 数据为什么 inline 存在 `WorldChunk.tile_map`；
- 普通 terrain tile 与 Stair entity 的职责区别；
- 视觉高度、世界 Z、逻辑 level 和 collision/traversable 的关系；
- atlas 缺 slice、重复 slice、越界 bounds 等加载不变量；
- 当前 level/stair/traversable 仍在演进中的部分应标为 WIP。

#### 5.2 新增 `rendering_pipeline.md`

必须覆盖：

- CPU `OffScreenBuffer` 到 Raylib texture upload 的完整路径；
- 为什么使用软件 framebuffer，以及相对直接 Raylib draw call 的取舍；
- world position、sim-relative position、buffer pixel、atlas source rect 四套坐标；
- Y 轴翻转和 Z 投影到 screen Y 的规则；
- entity foot anchor、body collision box、source anchor、trimmed-frame offset 的区别；
- terrain 先绘制、entity 后绘制的当前顺序；
- entity 遍历顺序不是可靠 depth sort 的限制；
- clipping、alpha blend、flipping、rotation 分别在哪一层处理；
- 如何用 debug overlay 验证视觉和碰撞锚点对齐。

现有 `draw_image_animation.md` 保留为底层专题，由新的渲染概览链接过去，避免把一篇文档继续膨胀成所有渲染知识的集合。

### 阶段 6：补齐玩法状态和平台外围

#### 6.1 新增 Actor 状态更新章节

可以放入 `entity.md`，也可以新增 `actor_state.md`。覆盖：

- player 的输入、加速度、阻尼、方向和动画状态；
- shark 的攻击状态转换；
- harpoon 从 non-spatial 到 spatial 再回收的状态机；
- animation time、flight time、fixed dt 的单位；
- gameplay update 在 simulation 前直接修改 LowEntity 的当前约定；
- 状态转换优先级和“一帧跨过多个时间阈值”的边界行为。

#### 6.2 修订 `platform_audio.md`

必须区分：

- 当前已有的 callback、ring buffer 和 sine producer；
- 主循环中 `update_audio` 当前被注释，因此实际只会消耗预填充内容；
- sample、frame、channel、byte 的单位；
- Raylib callback buffer size 参数的准确单位；
- producer/consumer index 的并发访问和 data race；
- full 与 empty 都表现为 `read == write` 的歧义；
- underrun、overrun、延迟的权衡；
- production cursor 应追赶 audio device，而不只是按渲染帧 dt 固定追加的替代设计。

#### 6.3 输入文档

输入模块较小时可以并入 `architecture_overview.md`：

- platform key state 如何映射到 game-facing `Input`；
- held state 与 transition count 的区别；
- 为什么 replay 记录的是抽象 Input，而不是操作系统事件；
- controller 扩展和多设备合并的边界。

### 阶段 7：把验证策略变成可核对事实

#### 7.1 修订 `testing.md`

先把当前没有正式测试和 `validate_world` 标为事实，把现有内容标成 Target。

建议落地顺序：

1. WorldPosition canonicalization 和负坐标；
2. tile coordinate 到 chunk/local coordinate；
3. entity index 插入、17 个 entity 扩 block；
4. 从非 first block 删除 entity；
5. 跨 chunk reindex；
6. collision rule 的新增、更新、清理和复用；
7. swept AABB 的贴边退出、角点、初始重叠和高速移动；
8. replay 的 EOF 循环和 snapshot 恢复。

文档应分别说明：

- 哪些已经有自动测试；
- 哪些只有 assert；
- 哪些依赖 debug overlay；
- 哪些只能通过 replay 或手感验证。

#### 7.2 增加文档维护检查

可以从低成本检查开始：

- Markdown 相对链接目标存在；
- guide 中引用的代码文件存在；
- README 中的构建命令能够执行；
- 旧标识符如 `HighEntity`、`GameState.entities`、`animate.odin` 不再冒充当前名称；
- 修改关键 struct 或常量时，代码评审 checklist 提醒同步 guide。

自动化只能发现名称和链接漂移，不能验证“为什么”的论证；架构主张仍需要人工复核。

### 阶段 8：去重和整理通识笔记

最后处理 `data_structure.md`、`store_vs_index.md`、`single_chain.md`：

- 把通用知识与本项目当前选择分开；
- 删除对话式残留，如“GPT 补充”“想深入了解哪个”；
- 合并重复的 storage/index、lifetime、free list 内容；
- 通识文章提供概念和替代方案，项目文章只记录本项目的决定；
- 无来源的性能数字改为定性描述，或补上可复现 benchmark。

不要优先做这一阶段。先让关键架构文档准确，再追求文风和去重。

## 推荐阅读顺序

整理完成后，文档应支持下面的阅读路径：

1. `README.md`：如何构建和运行；
2. `docs/guides/README.md`：文档地图；
3. `architecture_overview.md`：平台边界和一帧生命周期；
4. `game_memory.md`：状态放在哪里；
5. `entity.md`：长期游戏对象如何表示；
6. `world_position.md`、`world_chunk.md`：对象如何定位和查询；
7. `sim_region.md`：如何形成单帧工作集；
8. `collision.md`：工作集如何运动和交互；
9. `terrain_architecture.md`：世界静态内容如何组织；
10. `rendering_pipeline.md`、`draw_image_animation.md`：世界如何变成像素；
11. `dynamic_lib.md`、`platform_record.md`、`platform_audio.md`：平台能力；
12. `testing.md`：如何验证上述不变量。

## 执行 checklist

### P0：先建立可信主线

- [ ] 新增 `docs/guides/README.md`
- [ ] 新增 `architecture_overview.md`
- [ ] 重写 `entity.md`
- [ ] 重写 `sim_region.md`
- [ ] 修订 `world_chunk.md`
- [ ] 修订 `container_design.md`
- [ ] 重写 `game_memory.md`
- [ ] 重写 `data_lifetime.md`
- [ ] 扩写 `dynamic_lib.md`
- [ ] 重命名并重写 `platform_record.md`
- [ ] 修订 `collision.md`，区分 Current 与 Target

### P1：补齐重要模块

- [ ] 补充 collision rule 的设计和生命周期
- [ ] 新增 `terrain_architecture.md`
- [ ] 新增 `rendering_pipeline.md`
- [ ] 补充 Player/Shark/Weapon 状态更新设计
- [ ] 修订 `platform_audio.md`
- [ ] 修订 `testing.md` 并标注实际覆盖状态

### P2：提高可维护性

- [ ] 补充或合并 input 文档
- [ ] 核对 `world_position.md`
- [ ] 给所有架构 guide 增加状态和最后核对信息
- [ ] 加入链接、文件名和旧标识符检查
- [ ] 整理 `data_structure.md`、`store_vs_index.md`、`single_chain.md`
- [ ] 修正 README、CLAUDE 中的文件名、比例和轮询周期漂移

## 每次补文档的工作方式

每次只处理一个完整主题，建议按下面的节奏进行：

1. 阅读对应代码和直接调用者；
2. 写出当前事实、不变量和已知限制；
3. 从 git 历史确认某个奇怪选择是有意设计还是演进残留；
4. 把目标方案和当前方案分开；
5. 补充替代方案以及触发迁移的条件；
6. 检查交叉链接和代码名称；
7. 运行相关构建或测试；
8. 单独提交这个文档 checkpoint。

如果核对时发现代码疑似 bug，不要顺手把架构重写和 bug fix 混在同一个提交里。先在文档的 `Known limitation` 中记录，再用独立任务和提交修复代码。

## 本轮审计基线

- 审计日期：2026-09-04
- 当前 game dynamic library 可以构建。
- `odin test game` 和 `odin test platform` 均成功退出，但都显示 `No tests to run`。
- 审计时工作区的 `game/collision.odin`、`game/entity.odin`、`game/terrain.odin` 有未提交修改；后续涉及 Terrain 和 traversable 的文档需要在代码稳定后再次核对。

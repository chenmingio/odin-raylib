# 学习路线图

**目的**：规划从 Handmade Hero 基础引擎到 RimWorld / Dwarf Fortress / Factorio 风格模拟游戏的学习和开发路径
**适用于**：基础坐标、chunk、entity、碰撞、地图之后，不知道下一步系统如何拆解时使用
**最后更新**：2026-06-29

---

## 当前进度

Odin + Raylib 项目约完成 HH Day 035-040 的水平，已经有可继续扩展的 2D 模拟游戏底座。

| 系统 | 状态 | 对应 HH | 下一步 |
|------|------|---------|--------|
| 平台层（窗口、输入、热重载） | ✅ | Day 001-025 | 保持稳定 |
| Tilemap + 世界坐标 | ✅ | Day 026-035 | 扩展成多层地图数据 |
| Chunk 空间哈希 | ✅ | Day 055 | 继续服务 entity 查询和局部模拟 |
| 基础实体系统 | ✅ | Day 051（部分） | 补 ID、生命周期、组件式数据分区 |
| Aseprite 动画 | ✅ | HH 没有 | 够用即可 |
| 图片渲染 + Alpha 混合 | ✅ | Day 036-039 | 不作为主线投入 |
| SimRegion | 🟡 部分 | Day 063-065 | 补 end_sim、跨 chunk 回写 |
| 物理/碰撞 | ❌ | Day 041-050 | 先完成 AABB + 滑动 |
| 相机跟随 | ❌ | Day 052 | 跟随 sim focus entity |
| 实体行为（剑、AI、怪物） | ❌ | Day 059-069 | 不照搬，改造成任务/工作系统 |

---

## 目标游戏形态

这里的“类似 simWorld”先按**殖民地模拟 / 经营 / 涌现系统游戏**理解，而不是动作 RPG 或纯沙盒建造。

### 核心体验

玩家不是直接控制每个角色的每一步，而是通过区域、建筑、优先级、规则和命令影响世界。角色根据需求、工作、路径、资源和风险自行行动。

| 维度 | 推荐选择 | 原因 |
|------|----------|------|
| 视角 | 2D 俯视或轻等距 | 降低渲染负担，把精力放在模拟 |
| 地图 | tile grid + chunk | tile 适合寻路、建筑、房间、资源；chunk 适合局部加载 |
| 实体 | tile objects + mobile agents | 区分静态世界和可行动单位 |
| 时间 | 固定 tick 模拟 + 可变帧渲染 | 方便重放、调试、存档和性能控制 |
| 操作 | 玩家下命令，AI 执行 | 更接近 RimWorld / DF 的系统乐趣 |
| 复杂度增长 | 先深后广 | 每个系统有闭环后再加新系统 |

### 非目标

这些方向可以以后做，但不要在主线早期投入：

| 暂不追求 | 原因 |
|----------|------|
| 高级渲染、shader、光照 | 不是这类游戏的瓶颈 |
| 复杂物理刚体 | 殖民地模拟主要是 tile / AABB / 占用关系 |
| 多线程模拟 | 先把数据和 tick 做确定，再谈并行 |
| 大而全 ECS 框架 | 当前项目更适合先用明确结构体和数组 |
| 通用编辑器 | 先用 debug overlay 和简单工具解决问题 |

---

## HH 仍需学习的内容

只需要补 Day 041-065 里和当前项目直接相关的部分，其余按需查。

### 必须补完

| 集数 | 内容 | 为什么需要 | 本项目落点 |
|------|------|-----------|------------|
| Day 041-043 | 向量数学 + 运动方程 | 加速度、速度、drag | agent 移动、碰撞前积分 |
| Day 044-045 | 向量反射 + 运动搜索 | 碰撞后滑动 | AABB 撞墙和避障 |
| Day 046-047 | 多玩家 + 向量长度 | 归一化移动 | 输入移动和 AI 移动共用 |
| Day 048-050 | 线段相交 + Minkowski 碰撞 | 碰撞检测核心 | swept AABB |
| Day 051-054 | 实体更新频率分离 | SimRegion 基础概念 | 局部模拟、冷/热实体 |
| Day 055-058 | 哈希世界 + 空间分区 | 已完成大部分 | 查漏补缺，保证跨 chunk 正确 |
| Day 063-065 | SimRegion 完整实现 | begin/end 成对 | sim 回写、chunk 迁移 |

### 选看

| 集数 | 内容 | 说明 |
|------|------|------|
| Day 059 | Familiar AI（跟随） | 只看“目标驱动移动”的最小形式 |
| Day 060-061 | 血量 + 攻击 | 战斗不是主线，可借鉴实体交互 |
| Day 066-069 | 碰撞规则、空间查询 | 可作为后续完善碰撞层参考 |

### 可跳过

| 范围 | 内容 | 为什么跳过 |
|------|------|-----------|
| Day 071-095 | 3D 定位、楼梯、地面缓存、Render Group | 2D 模拟游戏不需要 |
| Day 096-175 | 光照、SIMD、多线程、资产系统、字体 | Raylib 已覆盖或不急 |
| Day 176-269 | Debug UI（90 集） | ROI 太低，可自建轻量调试面板 |
| Day 270-670 | 3D 渲染、光照研究、编辑器 | 完全不在当前主线 |

---

## 总体架构地图

模拟游戏的复杂度主要不是“某个算法很难”，而是**很多系统都要读写同一个世界状态**。因此路线图应该围绕数据所有权和更新顺序展开。

```
┌──────────────────────────────────────────────┐
│ 玩家意图层                                    │
│ 选择区域、下达建造/采集/搬运/优先级/禁区命令  │
├──────────────────────────────────────────────┤
│ AI 决策层                                     │
│ needs → job selection → reservation → action  │
├──────────────────────────────────────────────┤
│ 模拟系统层                                    │
│ 寻路、工作、库存、建筑、生产、战斗、事件、经济 │
├──────────────────────────────────────────────┤
│ 世界数据层                                    │
│ tile layers、chunks、entities、definitions     │
├──────────────────────────────────────────────┤
│ 平台/呈现层                                   │
│ Raylib 输入、渲染、音频、热重载、调试显示      │
└──────────────────────────────────────────────┘
```

### 推荐主循环

```
read_input()
build_player_commands()

accumulate_dt()
while accumulator >= fixed_tick_dt {
    process_commands()
    update_simulation_tick()
    accumulator -= fixed_tick_dt
}

render_interpolated_world()
render_debug_overlay()
```

关键原则：

| 原则 | 说明 |
|------|------|
| 固定 tick | AI、寻路、需求、生产、存档更容易确定 |
| 渲染只读 | 渲染不改变游戏状态 |
| 命令排队 | 输入先变成 command，再由模拟消费 |
| 数据定义和运行状态分离 | 物品、建筑、工作类型用 definition；数量、位置、进度是 state |
| 系统顺序显式 | 不要让系统互相递归调用，按 tick 阶段推进 |

---

## 地图与世界建模

碰撞和基础地图之后，下一步不是马上做 AI，而是把地图变成能支撑寻路、建筑、房间、资源和区域查询的数据模型。

### Tile 层级

推荐把一个 tile 拆成几层，不要用一个 enum 表达所有东西。

| 层 | 示例 | 主要用途 |
|----|------|----------|
| Terrain | 土地、水、岩石、肥沃土 | 移动成本、种植、采矿 |
| Floor | 木地板、石砖、泥地 | 美观、移动速度、房间价值 |
| Structure | 墙、门、工作台、床 | 阻挡、房间边界、交互目标 |
| Item Stack | 木材 x25、食物 x8 | 搬运、库存、生产消耗 |
| Zone/Designation | 储物区、砍树标记、建造蓝图 | 玩家命令和 AI 工作来源 |
| Fog/Visibility | 已探索、可见 | 信息展示和敌人生成 |

### Tile 和 Entity 的边界

| 用 tile | 用 entity |
|---------|-----------|
| 数量巨大、结构简单、按网格访问 | 需要独立生命周期和行为 |
| 地形、地板、墙体占用、区域标记 | 殖民者、动物、敌人、门、物品堆、建筑中的机器 |
| 寻路成本和阻挡信息 | 会移动、会被选中、会持有状态的东西 |

实践建议：

- 墙可以先是 tile structure，门可以是 entity，因为门有开关状态和交互行为。
- 物品堆可以是 entity，但在 tile 上维护 `first_item_entity_id` 或小数组索引，避免全局扫描。
- 建筑蓝图是 designation，不是正式建筑；材料到齐并完成工作后才变成 structure/entity。

### Chunk 分工

当前已有 `WorldChunk` 用于 entity 空间索引。模拟游戏里可以让 chunk 同时承担地图分页职责，但不要把所有逻辑塞进 chunk。

| 数据 | 是否按 chunk 存 | 说明 |
|------|----------------|------|
| tile layers | 是 | 大地图必须分页，chunk 内用固定二维数组 |
| entity index | 是 | 继续用现有空间哈希 |
| path cache | 可选 | 先不做；路径失效很麻烦 |
| room id / region id | 是 | flood fill 后写入 tile metadata |
| dirty flags | 是 | 某 chunk 地图变了，只重算相关系统 |

### 地图更新最佳实践

地图修改要通过少数入口完成，例如 `set_terrain`、`place_structure`、`remove_structure`、`set_designation`。入口负责设置 dirty 标记。

| 修改 | 需要标脏 |
|------|----------|
| 墙/门/障碍变化 | pathing、rooms、visibility |
| 地板变化 | beauty、room value、movement cost |
| 物品堆变化 | stockpile、job availability |
| 区域变化 | job generation |
| 温度源变化 | temperature |

不要在 AI、UI、渲染里直接改 tile 数组。否则后面会很难追踪“为什么寻路图没更新”。

---

## 碰撞、寻路和占用

殖民地模拟里需要同时处理两套移动概念：

| 系统 | 粒度 | 用途 |
|------|------|------|
| 碰撞 | 连续坐标 + AABB | 玩家角色、移动单位、局部避障 |
| 寻路 | tile graph | 长距离路线、工作目标选择 |
| 占用 | tile reservation | 防止多个单位抢同一个工作点或物品 |

### 推荐顺序

1. 完成 AABB 碰撞：角色不能穿墙，撞墙能滑动。
2. 建立 tile walkability：每个 tile 可走/不可走/成本。
3. 实现 A*：从 tile A 到 tile B，返回 tile path。
4. agent 沿 path 移动：把 tile path 转成连续坐标目标点。
5. 加 reservation：目标 tile、物品、工作台只能被一个 job 占用。
6. 加局部失败处理：路径堵住、目标消失、物品被拿走时取消 job。

### A* 最小实现

| 部分 | 推荐做法 |
|------|----------|
| 节点 | tile 坐标 |
| 邻居 | 先 4 方向，稳定后再考虑 8 方向 |
| 成本 | 默认 1，水/泥/门等增加成本 |
| 启发 | Manhattan distance |
| open set | 小地图可先线性扫描，性能不够再做 heap |
| 输出 | `[]TilePos`，调用者负责缓存或释放 |

### 什么时候不走碰撞

对 RimWorld 类游戏来说，墙体阻挡主要应该来自 tile walkability，而不是每个墙都作为碰撞 entity 参与 AABB 求解。AABB 更适合解决视觉上连续移动时的最后一层约束。

推荐规则：

- 长距离移动由 A* 决定。
- 每 tick 移向下一个 path waypoint。
- tile 不可走时路径失效并重算。
- AABB 只防止单位在连续坐标上重叠或穿过边界。

---

## 高级能力路线图

下面是“基础碰撞/地图之后”的主线。每个阶段都应该产出一个能玩的闭环，而不是只完成底层代码。

### 阶段 0：稳定底座

目标：世界能正确加载、移动、碰撞、回写。

| 能力 | 完成标准 |
|------|----------|
| `end_sim` | sim 内 entity 修改能写回 low entity |
| chunk 迁移 | entity 跨 chunk 后索引正确 |
| 相机跟随 | 以 focus entity 或选中实体为中心 |
| 固定 tick | 移动速度不受帧率影响 |
| debug 显示 | chunk 边界、entity id、碰撞盒、sim region |

不要进入 AI 前跳过这个阶段。否则后面的 bug 会混在一起，很难定位。

### 阶段 1：可编辑地图

目标：玩家可以改变世界，且系统知道哪些数据需要重算。

| 能力 | 完成标准 |
|------|----------|
| tile layers | terrain/floor/structure 分离 |
| 地图修改 API | 修改 tile 会设置 dirty flags |
| 建造蓝图 | 玩家放置 blueprint，不立刻生成成品 |
| 拆除/采集标记 | designation 能被 job 系统读取 |
| 简单 UI | 鼠标选择 tile，显示 tile 信息 |

最小 demo：玩家框选树木，生成“砍树 designation”；玩家放置墙蓝图，地图上显示待建造位置。

### 阶段 2：寻路与工作闭环

目标：殖民者能自己找事做、走过去、完成工作。

| 能力 | 完成标准 |
|------|----------|
| A* | 能绕过墙到达目标 |
| job board | 世界中可用工作集中登记 |
| worker state machine | `Idle -> ReserveJob -> MoveTo -> Work -> Finish` |
| reservation | job、目标物、目标 tile 不会被重复占用 |
| 失败恢复 | 路径失败或目标消失后释放 reservation |

最小 demo：玩家标记砍树，殖民者自动走到树旁，播放工作进度，完成后生成木材。

### 阶段 3：物品、库存和搬运

目标：资源从世界产生、被搬运、被消耗。

| 能力 | 完成标准 |
|------|----------|
| item definition | 木材、食物、石块有定义数据 |
| item stack entity | 同 tile 可堆叠同类物品 |
| inventory | pawn 可携带少量物品 |
| stockpile zone | 搬运目标由区域规则决定 |
| haul job | 地上物品能被搬到储物区 |

最小 demo：砍树生成木材，殖民者把木材搬到 stockpile。

### 阶段 4：建造与生产

目标：资源能转化成建筑和产品。

| 能力 | 完成标准 |
|------|----------|
| blueprint | 记录建筑类型、所需材料、目标 tile |
| material delivery | 搬运材料到蓝图 |
| construction job | 材料齐后执行建造工作 |
| workbench | 建筑可产生 bill / recipe |
| recipe | 输入物品 + 工作时间 -> 输出物品 |

最小 demo：玩家规划墙，殖民者搬木材并建成墙；工作台能把木材加工成简单产品。

### 阶段 5：需求、时间和 AI 决策

目标：角色不只是执行命令，也会照顾自己。

| 能力 | 完成标准 |
|------|----------|
| needs | 饥饿、困倦、娱乐、心情随时间变化 |
| schedule | 工作/睡觉/自由活动时间段 |
| utility scoring | 根据需求和工作优先级选择 action |
| interrupt | 饥饿过低时能打断低优先级工作 |
| memory/thought | 事件影响心情一段时间 |

推荐先用 utility scoring，不要一开始就做复杂行为树。

```
score_eat      = hunger_urgency * food_availability
score_sleep    = tiredness_urgency * bed_availability
score_work     = work_priority * job_distance_factor
score_recreate = mood_need * recreation_availability
```

最小 demo：殖民者工作一段时间后会饿，自己找食物吃，再回来继续工作。

### 阶段 6：房间、环境和基地价值

目标：地图结构影响角色行为和评价。

| 能力 | 完成标准 |
|------|----------|
| room flood fill | 墙和门围出房间 |
| room stats | 面积、清洁、价值、美观、温度 |
| ownership | 床/房间可分配给 pawn |
| environment effects | 房间质量影响心情 |
| dirty recompute | 墙/门变化后只重算附近区域 |

最小 demo：封闭房间被识别为 bedroom；床所在房间越好，睡醒心情越高。

### 阶段 7：事件、威胁和故事生成

目标：世界会给玩家制造压力和节奏变化。

| 能力 | 完成标准 |
|------|----------|
| event scheduler | 按时间或条件触发事件 |
| incident points | 根据人口、财富、时间估算事件强度 |
| threat spawn | 袭击、野生动物、灾害等 |
| trade visitor | 友好 NPC 带库存进入地图 |
| narrative log | 重要事件写入历史 |

先做可预测规则，再做随机故事。随机不是目标，能形成有意义的压力曲线才是目标。

### 阶段 8：存档、调试和内容扩展

目标：系统开始变多后，仍然能定位问题并长期扩展。

| 能力 | 完成标准 |
|------|----------|
| save/load | GameState 可序列化并恢复 |
| deterministic replay | 同输入同 seed 得到同结果 |
| debug inspector | 查看 tile、entity、job、reservation、path |
| sim profiler | 显示各系统 tick 耗时 |
| data definitions | item/building/job/recipe 从数据表加载 |

不要等所有玩法都完成才做存档。进入物品和建造后就应该开始设计序列化边界。

---

## AI 系统最佳实践

### 从状态机开始

早期用明确状态机比行为树更容易调试。

```
Idle
  -> FindJob
  -> ReserveJob
  -> MoveToTarget
  -> PerformWork
  -> DeliverResult
  -> Idle
```

每个状态只做三件事：

1. 检查前置条件是否仍然成立。
2. 推进当前动作的进度。
3. 成功、失败或被打断时返回明确结果。

### Job 不是 Action

| 概念 | 粒度 | 示例 |
|------|------|------|
| Job | 世界中的任务意图 | 砍这棵树、搬这堆木材、建这面墙 |
| Action/Toil | pawn 执行 job 的步骤 | 走到目标、等待 3 秒、生成物品 |
| Need | 角色内部压力 | 饿了、困了、心情差 |
| Reservation | 防抢占锁 | 这个物品/工作台/目标 tile 已被某人使用 |

如果把所有行为都做成 AI action，玩家命令、工作优先级、资源占用会很快混乱。把世界里可被执行的事情先表达成 job，再让 pawn 选择和执行 job。

### Job 数据建议

```
Job :: struct {
    id: Job_ID,
    kind: Job_Kind,
    target_entity: Entity_ID,
    target_tile: Tile_Pos,
    required_work: f32,
    remaining_work: f32,
    priority: i32,
    reserved_by: Entity_ID,
}
```

早期可以集中存 `jobs: [MAX_JOBS]Job`。等任务很多后，再按 chunk 或 job kind 建索引。

### Reservation 规则

任何会造成冲突的资源都要能被 reserve：

| 对象 | 例子 |
|------|------|
| Job | 砍树任务只能一个人做 |
| Entity | 同一堆木材不能被两个人同时搬 |
| Tile | 同一工作位置不能挤多个 pawn |
| Building slot | 同一个工作台交互点只能一个人占用 |

reservation 必须在 job 失败、pawn 死亡、目标删除时释放。建议做一个 `clear_reservations_for_entity(entity_id)` 的兜底入口。

---

## 数据和性能方向

### ID 与引用

不要长期保存裸数组下标。模拟游戏里实体会删除、重用、存档和加载。

推荐逐步演进：

| 阶段 | 引用方式 | 说明 |
|------|----------|------|
| 原型 | `u32 index` | 现有实现，简单 |
| 稳定期 | `{index, generation}` | 防止访问已删除实体 |
| 存档期 | stable id + runtime index | 存档里保存稳定 ID，加载后重建索引 |

### 定义数据和运行数据

```
Item_Definition: name, stack_limit, mass, nutrition
Item_State: def_id, count, position

Building_Definition: size, cost, work_required, passability
Building_State: def_id, hp, owner, active_recipe
```

这样后面加内容主要改数据，不需要到处改 switch。

### 何时优化

| 症状 | 优先优化 |
|------|----------|
| 寻路卡顿 | 限制每 tick 寻路数量、缓存失败、分帧计算 |
| job 查找慢 | 按 job kind / chunk 建索引 |
| 房间重算慢 | dirty chunk + 局部 flood fill |
| 物品扫描慢 | stockpile/item type 索引 |
| AI tick 慢 | 不同系统不同频率更新 |

早期不要做全局复杂缓存。缓存最难的是失效规则，地图和物品频繁变化时尤其容易出错。

---

## 开发计划

这是推荐顺序，不是固定日历。每一项都应该有可运行 demo 和可观察 debug 信息。

### 第一阶段：引擎基础（补完 HH）

```
1. 物理 + 碰撞
   - 运动方程：Delta = 0.5*ddP*dt² + dP*dt
   - swept AABB / Minkowski 碰撞
   - 碰撞响应（滑动）
   - debug：显示碰撞盒、法线、命中时间

2. SimRegion 完善
   - begin_sim 提取区域 entity
   - end_sim 回写 + chunk 迁移
   - entity 跨 chunk 测试
   - 相机跟随 sim focus

3. 固定 tick
   - 模拟固定 dt
   - 渲染使用当前状态即可，暂不做复杂插值
```

### 第二阶段：地图和工作原型

```
4. 多层 tile map
   - terrain / floor / structure / designation
   - tile dirty flags
   - 鼠标点选 tile inspector

5. A* 寻路
   - 4 方向网格寻路
   - 障碍物和移动成本
   - debug：画出 path、open/closed 可选

6. Job 系统
   - designation 生成 job
   - pawn 自动认领 job
   - reservation 防重复工作

7. 第一个闭环
   - 标记树木
   - pawn 走过去砍树
   - 生成木材
   - 木材可被搬到 stockpile
```

### 第三阶段：殖民地核心

```
8. 物品和库存
   - item definition
   - item stack entity
   - pawn carry inventory

9. 建造
   - blueprint
   - 搬材料
   - 建造进度
   - 完成后改变 structure layer

10. 需求系统
    - hunger / sleep / mood
    - food job
    - bed assignment

11. 房间系统
    - flood fill room detection
    - bedroom / stockpile / workshop
    - room stats 影响 mood
```

### 第四阶段：内容和压力

```
12. 生产链
    - recipe
    - workbench bill
    - 输入资源转输出资源

13. 事件系统
    - 天气、访客、袭击、疾病
    - 根据 colony wealth / pawn count 调整强度

14. 存档和调试
    - save/load GameState
    - replay seed
    - debug inspector：entity/job/path/reservation
```

---

## 推荐里程碑

| 里程碑 | 玩家能做什么 | 系统验证点 |
|--------|--------------|------------|
| M1：碰撞沙盒 | 控制角色绕墙走 | AABB、chunk、sim 回写 |
| M2：地图编辑 | 放墙、拆墙、标记树 | tile layers、dirty flags |
| M3：自动砍树 | 框选树，pawn 自动砍 | A*、job、reservation |
| M4：搬运储物 | 资源自动进仓库 | item stack、stockpile、haul |
| M5：建造房间 | 规划墙和床，pawn 建成卧室 | blueprint、材料、room flood fill |
| M6：基本生存 | pawn 会吃饭睡觉工作 | needs、utility scoring |
| M7：生产链 | 工作台按订单生产 | recipe、bill、库存查询 |
| M8：事件压力 | 袭击/天气影响基地 | event scheduler、战斗或灾害 |
| M9：可长期玩 | 存档、加载、调试定位 | serialization、inspector |

---

## 学习资源

### 书籍

| 书 | 作者 | 重点 |
|----|------|------|
| **Designing Games** | Tynan Sylvester（RimWorld 作者） | 涌现设计、反馈循环、有意义的选择 |
| **AI for Games** | Ian Millington | 行为树、状态机、寻路、决策 |
| **Game Programming Patterns** | Robert Nystrom | 命令、状态、观察者、数据驱动 |

### 网站

| 资源 | 地址 | 重点内容 |
|------|------|---------|
| **Red Blob Games** | https://www.redblobgames.com/ | A* 寻路、网格、视野、地图生成 |
| **Factorio Friday Facts** | https://factorio.com/blog/ | 优化思路、设计决策、调试工具 |
| **RimWorld Modding Wiki** | https://rimworldwiki.com/wiki/Modding_Tutorials | defs、jobs、work givers 的组织方式 |

### Red Blob Games 必读

| 文章 | 用途 |
|------|------|
| Introduction to A* | 寻路基础 |
| Grid pathfinding optimizations | 了解什么时候需要优化 |
| Line of Sight | 视野 / 战争迷雾 |
| Map generation | 地图生成 |
| Hexagonal Grids | 仅在决定用六角格时读 |

### 反向工程

| 方法 | 说明 |
|------|------|
| RimWorld 反编译 | C# 可用 ILSpy 查看 jobs、work givers、needs、defs |
| RimWorld Modding Wiki | 了解数据结构和系统组织 |
| Factorio FFF | 学性能调试、确定性、工具建设 |

---

## 关键原则

| 原则 | 说明 |
|------|------|
| 做游戏，缺什么学什么 | 不要预先学完所有系统 |
| 每阶段有闭环 | “能砍树并搬走木材”比“写完泛型 AI 框架”更有价值 |
| 地图修改必须集中入口 | 方便维护 dirty flags 和派生数据 |
| Job 是世界事实 | AI 选择 job，不要让每个 pawn 自己全图扫描 |
| Reservation 是硬规则 | 先防抢占，再谈智能 |
| 渲染够用就行 | 方块和图标足够验证模拟 |
| Debug 是玩法系统的一部分 | 没有 inspector，复杂模拟不可维护 |
| 数据定义和状态分离 | 内容扩展靠 definition，不靠复制代码 |
| 系统间解耦 | 需求系统不依赖渲染，寻路不依赖 AI |
| 先确定，再随机 | 事件和 AI 要先可解释，再加随机性 |

---

## 参见

- [sim_region.md](./sim_region.md) — SimRegion 实现指南
- [collision.md](./collision.md) — 碰撞系统设计
- [world_chunk.md](./world_chunk.md) — Chunk 空间索引
- [entity.md](./entity.md) — 实体系统
- [world_position.md](./world_position.md) — 世界坐标系统
- [testing.md](./testing.md) — 测试策略

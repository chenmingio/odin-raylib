# Handmade Hero Day 070–080 学习与移植计划

更新日期：2026-09-24。本文是后续实施计划；状态来自静态代码核对，尚未进行游戏运行验收。

## 目标

这一阶段的主线不是“给 2D 游戏加一个楼梯对象”，而是逐步回答下面的问题：

> 当实体、碰撞体、地面和房间都拥有 Z 高度时，如何判断实体应该被模拟、能否相撞、站在哪里，以及是否可以进入或离开一块可行走区域？

最终应得到这些能力：

- 世界位置、模拟位置、速度和模拟边界统一使用三维坐标。
- 实体具有真实高度；位于不同高度的实体不会错误地互相阻挡。
- 楼梯根据实体在楼梯上的位置连续给出地面高度。
- 实体可以拥有多个局部碰撞体。
- 用显式 room/Space 描述允许移动的区域；高度支撑与区域边界分别处理。
- 移动循环同时处理“撞进实体”和“走出可行走区域”两种边界。

课程索引：[Handmade Hero Episode Guide](https://guide.handmadehero.org/)。最终代码基准使用用户提供的独立快照：

```text
/Users/chenming/Documents/code.chenming.com/Games/handmade-hero-tutorial/casey-origin-code/handmade_hero_day_080_source/code/
```

重点对照 `handmade_sim_region.cpp` 的 `MoveEntity`、`EntitiesOverlap`、`SpeculativeCollide`，`handmade_sim_region.h` 的碰撞体结构，`handmade_entity.h` 的 ground point，以及 `handmade.cpp` 的实体/房间构造。

**范围约定**：下文的“完成标准”是本项目移植后的验收目标，不表示 Casey 在每集结尾都已经解决了全部边界问题。Day 080 仍保留 `Ground = 0.0f` 默认值、楼梯进出 TODO，以及主要基于 XY sweep + Z 区间筛选的运动；它不是完整三维刚体、任意楼板落地或悬崖坠落系统。

## 当前 Odin 项目的起点

| 当前代码证据 | 状态 | 本阶段剩余工作 |
|---|---|---|
| `world.odin`：`WorldPosition`、逐轴 canonicalization；`entity.odin`：位置、速度、加速度、size 均为 V3 | 已有三维数据基础 | 让 Z 真正参与高度支撑和碰撞判定 |
| `sim_region.odin`：遍历 XYZ chunk，以 `overlap_box(camera_bounds, entity_size_box(...))` 判定 updatable | 已有体积相交判断 | 审计查询边界、最大半径/速度假设；切换复合体后使用 total volume |
| `collision.odin`：自碰撞排除、双方 collides 检查；`collision_rules.odin`：pairwise rules | Day 69–70 基础已有 | 回归 owner 排除、单次伤害、回收后规则清理 |
| `sim_region.odin`：单独积分 Z，sweep 只传 `remaining_delta.xy` | 高度运动未完成 | 重力、支撑、Z 区间筛选、楼梯求高 |
| `entity.odin` / `terrain.odin`：已有 `.Stair`、方向、level；`add_stair_grass` 已生成实体 | 楼梯数据占位 | 目前未设置楼梯 size/碰撞行为；补 walkable 范围和高度函数 |
| `terrain_layout.odin`：已有主岛、高台和左右楼梯布局；tile 写入 Z chunk 0 | 已有视觉场景 | 将视觉 level 映射为物理高度、room 和楼梯连接，不能把图片上移当作上楼 |
| `entity.odin`：已有 traversable bool，但没有 Space 类型和对应运动分支 | 字段占位 | Day 79–80 实际接入可通行区域 |
| `SimEntity.low_entity: ^LowEntity`；`TODO.md` 的 Day 64 项 | 引用映射仍待完成 | 可先建立唯一 ID 映射；完整副本改造单独安排 |

另一个必须先统一的约定：`entity_size_box` 将 XY 视为中心、Z 视为底部；`high_entity_rect_center` 又给 Y 加半高。需要明确物理脚点、碰撞体 offset 和绘图 anchor 的关系，避免查询与碰撞使用不同的体积。

## 完成以后可以玩到什么

以下为需要随功能一起制作的验收场景，不是当前已实现的互动。

| 阶段 | 功能点 | 玩家可亲自验证的新互动 |
|---|---|---|
| 71–72 | 重力、Z 速度、三维范围查询 | 接入一个不冲突的跳跃动作后，原地跳起落下；靠近镜头/楼层边缘时碰撞物仍有效 |
| 73–75 | 楼梯 overlap、斜面求高、step height、支撑 | 从低端走上高台，再从高端走下；高度不匹配的侧面不能直接穿上去 |
| 76–77 | 实体高度、Z 筛选、统一脚点 | 在上下两层相同 XY 位置活动而不误撞；跳起后脚底高于低障碍时越过，落地后仍被它阻挡 |
| 78 | 多个局部碰撞体 | 绕过 L 形障碍，穿过两个实体部件之间足够宽的缺口，不再被整体包围盒挡住 |
| 79–80 | room/Space 与 traversable 边界 | 在主岛、高台及连接区内探索；走到无连接的区域边缘被挡住，合法房间连接处能连续通过 |

推荐最终做一个 **“主岛 → 楼梯 → 高台 → 下楼返回”** 的小关卡，并放置低障碍、复合障碍和不同高度的战斗目标。旧武器伤害继续工作；在命中检查复用 Z 筛选后，用“同高度命中、不同高度不命中”验证高度对战斗的影响。这里不新增敌人寻路、跨层追击或新的攻击系统。

**可选后续玩法，不计入 70–80 完成要求**：跳崖落到下层、掉坑重生、桥下穿行与任意楼板落地、开关门/机关事件、怪物自动上下楼。它们需要额外的支撑面选择、垂直碰撞、事件或寻路设计；仅加 traversable 不会自动获得这些能力。

## 开始 Day 071 前的前置检查点

建议先完成或明确冻结下面三项，避免在楼梯逻辑中同时调试旧问题：

1. 审计 `TODO.md` 中 Day 64 的引用问题，至少保证一个 storage index 在同一 SimRegion 内唯一。若当前不需要递归加载关联实体，可先验证现有加载不重复，完整引用解析另设 checkpoint，不把完整副本重构绑进楼梯工作。
2. 为移动测试建立固定小场景：一个玩家、一个普通墙、一个低墙、上下两层房间、连接两层的楼梯。
3. 给碰撞体、ground point、当前 ground 高度和 SimRegion 边界准备 debug drawing；这一阶段只看最终画面很难定位 Z 错误。

每集使用独立 commit。先写本集的失败场景，再实现，再对比相邻两天源码，而不是一开始照抄 Day 080。

## 分集计划

### Day 070 — Exploration To-do List

课程页：[Day 070](https://guide.handmadehero.org/code/day070/)

**主要问题**

回顾探索阶段还缺哪些系统，并决定下一条主线。代码方面只修补已有碰撞系统，不引入完整的新玩法。

**新增或确认的能力**

- `can_collide(a, b)` 必须拒绝实体与自身碰撞。
- 检查矩形扩张函数对 X/Y 半径的使用是否正确。
- 明确 collision-rule hash 删除任意实体相关规则时的复杂度和取舍。
- 把接下来优先级定为：Z、3D 碰撞、上下楼和地面。

**先自己尝试**

- 列出当前 Odin 代码中所有“虽然类型是 V3，但逻辑仍假定 2D”的位置。
- 写出实体和自己、武器和 owner、武器重复命中的三组断言。
- 不急着优化规则删除；先判断现有全表扫描是否真是当前瓶颈。

**完成标准**

- 上述碰撞规则场景都有确定结果。
- 形成一份具体的 3D 化缺口清单。当前项目最近的碰撞规则提交已经覆盖了本集大部分代码工作，所以本集可以是审计型 checkpoint。

### Day 071 — Converting to Full 3D Positioning

课程页：[Day 071](https://guide.handmadehero.org/code/day071/)

**主要问题**

旧代码把 XY 移动与单独的 `Z/dZ` 拼在一起，导致世界位置、SimRegion、运动积分和碰撞使用不同的坐标模型。

**新增特性**

- 实体 `p`、`dp`、`ddp` 统一为 V3。
- SimRegion 的 bounds/updatable bounds 升级为三维 box。
- 世界 chunk 尺寸和坐标运算支持逐轴 V3 运算。
- 重力作为 Z 方向加速度进入同一运动方程。
- 先保留临时的 `z >= 0` 地面钳制，后续再替换为真实 ground。

**先自己尝试**

- 搜索所有 `.xy`、V2 尺寸、只循环 X/Y chunk、硬编码 `z = 0` 的位置并分类。
- 先只让玩家跳起、落回零平面；暂时不要同时做楼梯。
- 决定实体 `p.z` 代表中心、底部还是别的基准点，并把临时决定写在结构体注释中。

**完成标准**

- 实体可以拥有 Z 速度并受重力影响。
- SimRegion 能从相邻 Z chunk 加载实体。
- 现有 XY 移动和墙体碰撞没有回归。

### Day 072 — Proper 3D Inclusion Tests

课程页：[Day 072](https://guide.handmadehero.org/code/day072/)

**主要问题**

判断“实体的中心点是否在 SimRegion 内”会漏掉中心在外、碰撞体却伸入区域的大实体；移动实体也可能在一帧内从区域外进入。

**新增特性**

- 用实体尺寸扩张查询 box，再测试实体中心，即 Minkowski inclusion test。
- updatable bounds 额外包含最大实体半径。
- 加载 bounds 额外包含 `max_radius + dt * max_velocity` 安全边界。
- 为最大速度建立可验证的约束。
- 当前实体尺寸已经是 V3；核对构造时高度非零且与物理含义一致。

**先自己尝试**

- 构造一个中心刚好在相机边界外、体积与边界相交的实体。
- 构造一个本帧能高速穿入 updatable bounds 的实体。
- 先在纸上画出“扩张区域”和“扩张实体”两种等价视角，再写判断函数。

**完成标准**

- 两个边界用例都会被加载，且只有真正落入 updatable bounds 的实体会被更新。
- 大实体和高速实体不会在画面边缘突然出现或漏模拟。

### Day 073 — Temporarily Overlapping Entities

课程页：[Day 073](https://guide.handmadehero.org/code/day073/)

**主要问题**

楼梯、触发区一类对象允许实体进入其体积，但仍需要知道实体是“刚进入、正在内部、还是刚离开”。普通的阻挡碰撞不能表达这种关系。

**新增特性**

- 加入 `Stairwell` 实体类型和最小测试楼梯。
- 在一次移动中记录起始时已经重叠的实体。
- 区分新发生的边界穿越和已有重叠。
- 为非阻挡交互探索临时碰撞规则或 overlap bookkeeping。

**先自己尝试**

- 先记录移动前后的重叠状态；enter/stay/exit 日志可作为辅助实验，不要求建立通用事件系统。
- 用一个不阻挡玩家的矩形触发区验证事件，不要先写楼梯高度插值。
- 思考 overlap 状态应该跨帧保存，还是能从每帧几何关系重建。

**完成标准**

- 玩家可进入和离开触发区，不会被当成墙挡住。
- 能解释初始已重叠和本帧新接触为何需要不同处理。

**注意**

本集方案是探索原型。Day 074 会删除局部 `OverlappingEntities` 方案并分离碰撞与重叠谓词。建议保留本集 commit 供比较，但不要把它当成最终接口。

### Day 074 — Moving Entities Up and Down Stairwells

课程页：[Day 074](https://guide.handmadehero.org/code/day074/)

**主要问题**

楼梯既不是普通墙，也不是单纯触发器：它在 XY 范围内定义了一个随位置变化的支撑高度。

**新增特性**

- 将交互拆为 `can_collide`、`can_overlap`、`handle_overlap`。
- 楼梯不进入普通阻挡碰撞，但参与 overlap 查询。
- 根据实体在楼梯 Y 方向的归一化位置插值得到 ground Z。
- 移动结束后把实体钳制到求得的 ground。
- 引入 `moveable` 标记，避免静态空间实体进入移动积分。

**先自己尝试**

- 写纯函数 `stair_ground(stair, xy) -> z`，单独测试底端、中点、顶端和范围外钳制。
- 让角色匀速横穿楼梯，不加跳跃，观察 Z 是否单调连续。
- 本阶段先只放一条楼梯，避免多个候选支撑歧义；不能直接取所有重叠地面的最高值，否则可能吸附到上层。多支撑面选择留作后续设计。

**完成标准**

- 玩家从低层走上楼梯时 Z 连续升高，从另一端走下时连续降低。
- 楼梯不会像普通墙一样阻挡整个侧面。

### Day 075 — Conditional Movement Based on Step Heights

课程页：[Day 075](https://guide.handmadehero.org/code/day075/)

**主要问题**

只要重叠楼梯就直接修改 ground，会让角色从错误的高度瞬移到楼梯，或从楼梯边缘走进不可到达的高度。

**新增特性**

- `speculative_collide`：在候选碰撞点比较 mover ground 与目标 ground。
- 只有高度差在允许的 `step_height` 内才允许进入或离开楼梯。
- 引入 `z_supported` 状态；有支撑时不施加重力，失去支撑时恢复重力。
- 楼梯本身重新参与候选边界检测，但最终是否阻挡由台阶高度决定。

**源码差异提醒**：Day 080 的 `SpeculativeCollide` 仍使用当前 ground point；调用方虽然计算 `TestP`，却没有传入。候选位置判定是本项目的稳健性改进，不能直接照抄后宣称已完成。源码也明确保留了离开楼梯的 TODO。

**先自己尝试**

- 分别写“从低端进入”“从高端进入”“从侧边进入”“从楼梯走出到空中”四个场景。
- 不要只检查当前位置；用候选接触位置估算目标 ground。
- 把 `max_step_height` 做成 mover 的能力或 move spec 参数，不要散落魔法数。

**完成标准**

- 低端可正常上楼，高端高度匹配时可正常下楼。
- 角色不能从楼梯侧面或错误楼层瞬移到斜面。
- 主动跳起后受重力回落；任意悬崖离地与落向下层不作为本集保证。

### Day 076 — Entity Heights and Collision Detection

课程页：[Day 076](https://guide.handmadehero.org/code/day076/)

**主要问题**

即使坐标已经是 V3，若 swept AABB 仍只看 XY，高处飞过的实体仍会撞上低墙，不同楼层也会错误互相阻挡。

**新增特性**

- 每种实体拥有明确的 X/Y/Z 碰撞尺寸。
- 用 `add_grounded_entity` 统一“给定地面点，放置中心碰撞体”的偏移规则。
- 只有两个碰撞体的 Z 区间重叠时才执行 XY swept collision。
- 世界的 tile side 与 tile depth 分开定义。

**先自己尝试**

- 用三个用例驱动实现：同高度撞墙、高于墙顶通过、刚好贴着墙顶通过。
- 明确 Z 区间采用半开还是闭区间，避免相邻楼层仅边界接触就互撞。
- 画出碰撞体底面和顶面，不要用 sprite 高度代替物理高度。

**完成标准**

- 同高度实体仍正常碰撞。
- 底部高于低墙顶部的实体可通过。
- 位于相邻楼层、XY 重叠的实体不会互相阻挡。

### Day 077 — Entity Ground Points

课程页：[Day 077](https://guide.handmadehero.org/code/day077/)

**主要问题**

用实体中心做位置基准会让不同高度的碰撞体、楼梯插值、阴影和渲染偏移反复加减半高，语义很容易混乱。

**新增特性**

- 明确定义 `get_entity_ground_point`。
- 楼梯的 `walkable_dim` 和 `walkable_height` 与实体总碰撞尺寸分离。
- `get_stair_ground` 接收 mover ground point，而不是碰撞体中心。
- 阴影和渲染以 ground point 为共同锚点。

**先自己尝试**

- 给 `p`、ground point、collision center、sprite anchor 四个概念各写一句不含糊的定义。
- 对不同身高实体验证：站在同一地面时 ground Z 相同，但碰撞体中心 Z 不同。
- 检查阴影是否留在地面，而不是随实体中心错误漂移。

**完成标准**

- 楼梯求高不再依赖 mover 自身高度。
- 高矮实体站在同一层时脚底和阴影对齐。
- 后续碰撞体增加 offset 时不需要改变世界位置语义。

### Day 078 — Multiple Collision Volumes Per Entity

课程页：[Day 078](https://guide.handmadehero.org/code/day078/)

**主要问题**

单个 AABB 无法紧凑表示 L 形房间、复杂角色或由多个部件组成的障碍；但所有查询都遍历全部小体积又会让 broad phase 变复杂。

**新增特性**

- `CollisionVolume { offset_p, dim }`。
- `CollisionVolumeGroup { total_volume, volumes }`。
- total volume 用于 SimRegion inclusion 和 broad phase。
- 每对实际 volume 用于窄相碰撞。
- 各实体类型共享不可变的 collision group；null entity 使用空 group。

**先自己尝试**

- 先做一个由两个不相交 box 构成的实体，验证中间空隙不会碰撞。
- 写 group 构造器自动计算 total volume，避免手工维护包围盒。
- 决定 collision group 的生命周期和所有权；它应长期存在，不应在每帧分配。

**完成标准**

- 单 volume 实体行为不变。
- 两个复合实体会遍历所有 volume 对并选择最早碰撞。
- SimRegion 只需要检查 total volume 就不会漏加载子体积。

### Day 079 — Defining the Ground

课程页：[Day 079](https://guide.handmadehero.org/code/day079/)

**主要问题**

需要把“哪里允许移动”变成世界数据，用房间体积限制活动范围。本集引入 Space 数据；真正限制离开区域要到 Day 080，默认 ground 高度仍是独立问题。

**新增特性**

- 增加 `Space`/room 实体类型。
- 增加 `traversable` 标记，与 `collides` 明确区分。
- 每个标准房间创建一个覆盖房间范围的 traversable collision volume。
- `can_collide` 只在双方都具有 collides 属性时成立。
- debug rendering 画出 traversable volume 边界。

**先自己尝试**

- 暂时移除一个房间的 Space，观察调试轮廓消失；到 Day 080 再验证活动范围约束。不要以自动掉落作为本集验收。
- 写清楚 solid volume 与 traversable volume 的集合含义：前者不能进入，后者不能随意离开。
- 允许多个 traversable 重叠，为楼梯与上下层房间交界做准备。

**完成标准**

- 每间房都有显式可视化的可行走范围。
- traversable space 不会像墙一样阻止内部移动。
- 房间范围已成为可查询的数据；离开范围的运动限制留给下一集。

### Day 080 — Handling Traversables in the Collision Loop

课程页：[Day 080](https://guide.handmadehero.org/code/day080/)

**主要问题**

只在移动结束后查询 overlap 太晚：实体可能一步跨出房间、穿过狭窄 ground，或者在 solid 与 traversable 边界中选错停止点。

**新增特性**

- `entities_overlap` 支持复合碰撞体与小 epsilon。
- traversable 也进入 sweep 候选循环。
- 对 solid 求最早“进入”时间 `t_min`。
- 对当前重叠的 traversable 候选求退出边界，并取最大的有效退出参数 `t_max`，保留重叠区域提供的继续移动空间；不能取各区域退出时间的最小值。
- 最终取 `t_stop = min(t_min, t_max)`，保留对应边界和法线以处理滑动。
- overlap/ground 处理复用统一的 multi-volume 几何测试。

**先自己尝试**

- 把问题画成一条参数化线段：`p(t) = p0 + t * delta`，分别标出进入 solid 和离开 traversable 的 t。
- 建立四个场景：房间内部移动、撞墙、走向没有地面的门口、从房间进入重叠的楼梯/下一房间。
- epsilon 只用于几何稳健性，并集中定义；不要用它掩盖错误的 ground 或 offset。

**源码边界**：该算法依赖当前重叠候选和有限次移动迭代，不是任意区域并集的完整连续求交。需额外验证高速跨越多个房间、初始不在任何 Space（源码 `tMax` 初始为 0）和零 XY 位移。楼梯负责高度，Space 负责允许移动的范围，两者需共同覆盖连接处。

**完成标准**

- 玩家不能走出唯一的 traversable room 落入虚空。
- solid wall 与 room 边界同时存在时，停止在更早的边界。
- 两个 traversable 合法重叠时，可以从一个连续进入另一个。
- 楼梯上下端与上下层房间衔接时没有卡边、瞬移或掉落。

## 推荐实施顺序和 checkpoint

不要把 11 集压成一个大提交。建议按下面的风险边界执行：

1. **Baseline**：审计 Day 64 唯一加载、统一坐标基准，固定测试场景和 debug drawing。
2. **Day 070**：碰撞规则审计与测试。
3. **Day 071**：统一 V3 和重力。
4. **Day 072**：SimRegion 体积查询和安全边界。
5. **Day 073**：独立 overlap 实验，保留探索 commit。
6. **Day 074**：重构 overlap，并完成基础楼梯求高。
7. **Day 075**：step height 与支撑状态。
8. **Day 076–077**：真实实体高度和 ground-point 语义。
9. **Day 078**：复合碰撞体；先保持所有已有实体只用一个 volume。
10. **Day 079**：显式 room/ground/traversable 数据。
11. **Day 080**：把 traversable 边界并入 sweep，做完整回归。

Day 080 完成后再考虑渲染美化。课程中的 `ZFudge` 是探索性显示手段，不应成为物理或世界坐标的一部分。

## 每集固定学习流程

1. 只看课程标题和本计划中的“主要问题 / 完成标准”。
2. 在测试场景中先复现一个当前失败行为。
3. 自己画数据和几何关系，写出最小接口。
4. 实现并运行 focused verification。
5. 查看课程 index 的时间点，再观看 Casey 的设计过程。
6. 对比相邻源码快照，而不是只读 Day 080 最终文件。
7. 写三条笔记：自己的方案、Casey 的方案、为何保留其中一个。
8. 检查 `git status --short` 和相关 diff，只提交本集文件。

当前确认可用的是独立 Day 080 快照。若另有相邻日期源码，再对比相应 `code/` 目录；没有相邻快照时，按各集 guide 时间索引理解演进，以 Day 080 验证最终数据和调用关系。

## 本项目的落地清单

所有勾选项表示待实现并验收；上文“已有”仅代表读代码确认的基础。

| 完成 | 检查点 | 主要文件 | 可交付结果 |
|---|---|---|---|
| [ ] | 70 / 起点审计 | `game/collision.odin`、`game/sim_region.odin` | 统一脚点/中心定义；保存旧移动、武器命中的基线 |
| [ ] | 71–72 / Z 运动 | `game/player.odin`、`game/sim_region.odin`、`game/controller.odin`、`platform/input.odin` | 跳跃输入、重力、XY 阻尼与 Z 分离、范围与速度约束 |
| [ ] | 73–75 / 楼梯 | `game/entity.odin`、`game/terrain.odin`、`game/sim_region.odin`、`game/collision.odin` | 楼梯范围、求高、step height、支撑状态 |
| [ ] | 76–77 / 高度与脚点 | `game/collision.odin`、`game/game_init.odin`、`game/render_entity.odin`、`game/render_debug.odin` | Z 区间筛选，物理脚点与 sprite anchor 分离，显示脚点/高度 |
| [ ] | 78 / 复合体 | `game/entity.odin`、`game/game_init.odin`、`game/collision.odin`、`game/sim_region.odin` | 长期存储的 collision group、包围体及逐 volume 查询 |
| [ ] | 79–80 / 活动范围 | `game/terrain_layout.odin`、`game/terrain.odin`、`game/sim_region.odin`、`game/collision.odin` | Space 构造、退出边界、重叠连接和滑动 |
| [ ] | 小关卡验收 | `game/terrain_layout.odin`、`game/render_debug.odin` | 主岛往返高台、低障碍、复合缺口、跨高度命中对照 |

实施注意：

- `update_player` 当前的 `-player.dp * 5` 会作用到 Z；加跳跃时将地面阻尼限定到 XY，重力统一在运动求解中施加。
- 当前左右楼梯来自 `StairDirection`，先确认贴图方向和真实上坡轴的对应关系；不要直接把 Casey 的 Y 方向插值用于全部楼梯。
- tile 的视觉 level 与物理楼层共用明确的高度换算；地表图片负责显示，Space 和楼梯实体负责物理。
- 保留现有 Odin/Raylib 软件渲染与素材方案；本阶段无需移植 Windows 平台层或 Day 81 以后的地面贴图缓存。
- 每个 checkpoint 记录手动操作、预期结果和实际结果；几何纯函数适合做针对性的断言。修改代码后按 README 构建，文档更新本身不需要运行游戏测试。

## 最终回归清单

- 玩家、武器、怪物的旧 XY 碰撞和滑动没有回归。
- 实体不会与自身碰撞，pairwise rule 仍可覆盖通用规则。
- 大实体在 SimRegion 边缘不会漏加载。
- 不同 Z 层但 XY 重叠的实体不会误撞。
- 飞行实体可越过低墙，落地后恢复正常碰撞。
- 楼梯四种进入方向都有确定行为，非法侧向跨层会被阻止。
- 高矮实体共享 ground point 语义。
- 复合碰撞体的空隙不会产生假碰撞。
- 不能从合法 Space 走入无连接区域；非法出生点有明确诊断。
- room-room、room-stair、stair-room 三种过渡连续稳定。
- fixed tick、录制回放和热重载仍可工作。改变永久存储 struct 布局时，重启并重新录制，避免拿旧内存/旧回放误判新逻辑。

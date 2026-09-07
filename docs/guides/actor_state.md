# Actor 状态更新

| 字段 | 内容 |
|---|---|
| Status | Draft（框架） |
| Code scope | `game/player.odin`、`game/shark.odin`、`game/entity.odin`、`game/game.odin` |
| Last verified | TODO |

> 本文讨论 Player、Shark 和 Harpoon 的玩法状态与更新顺序。Entity 的存储和引用模型见 [Entity](entity.md)，运动与碰撞见 [SimRegion](sim_region.md) 和[碰撞系统](collision.md)。

## 要解决的问题

<!-- TODO: 为什么 gameplay state update 不应散落在 render/collision 中？当前代码是怎样划分的？ -->

## Actor、Entity 与 SimEntity 的关系

<!-- TODO: Actor 是概念还是独立类型？哪些状态直接存在 LowEntity？ -->

| 数据 | Player | Shark | Harpoon | 所属关注点 |
|---|---|---|---|---|
| position / dp / ddp | TODO | TODO | TODO | movement |
| status / animation time | TODO | TODO | TODO | state/render |
| owner / weapon | TODO | TODO | TODO | relationship |
| flight time / target | — | — | TODO | projectile |

## 每帧调用顺序

```text
Input
  -> update_player
  -> update_shark_state
  -> camera follows player
  -> begin_sim
  -> simulate movement/collision
  -> render
  -> end_sim
```

<!-- TODO: 核对顺序，说明各阶段读到的是模拟前还是模拟后的状态。 -->

## Player 状态机

### 输入到运动意图

<!-- TODO: WASD、normalize0、对角线速度。 -->

### 加速度与阻尼

<!-- TODO: player_rfd、ddp、dp，解释单位和选择依据。 -->

### 动画状态优先级

```text
Attack 1 / Attack 2
  > moving
  > idle
```

<!-- TODO: held button、重复攻击、状态切换时 timer reset。 -->

## Shark 状态机

<!-- TODO: 用状态图替代只复述 if/else。 -->

```text
Idle
  -> Throw preparation
  -> release harpoon
  -> Idle
```

必须说明：

- 距离判断使用什么坐标；
- 动画阈值 400ms/700ms 的来源；
- 一帧跨过多个阈值时发生什么；
- direction 在何时锁定；
- shark 已有 Run 分支但如何进入。

## Harpoon 生命周期

```text
stored non-spatial entity
  -> make spatial at release
  -> ballistic movement
  -> collision event/rules
  -> flight time expires
  -> become non-spatial
  -> clear collision rules
```

<!-- TODO: 每个箭头对应哪个函数，哪些字段需要 reset。 -->

### 为什么复用同一个 Entity

<!-- TODO: 相比每次 create/destroy projectile 的收益和状态清理风险。 -->

### Owner 与 Weapon 引用

<!-- TODO: storage index 的优势、index reuse 风险、未来 SimEntity reference mapping。 -->

## Gameplay 与 Collision 的职责边界

| 决策 | 当前负责模块 | 备选位置 | 取舍 |
|---|---|---|---|
| 是否发生几何碰撞 | TODO | TODO | TODO |
| 是否阻挡移动 | TODO | TODO | TODO |
| 是否扣血 | TODO | TODO | TODO |
| 是否允许再次命中 | TODO | TODO | TODO |

## 时间与确定性

<!-- TODO: fixed dt、毫秒整数、f32 timer、animation time 和 replay。 -->

## 关键不变量

- [ ] non-spatial Harpoon 不存在于 WorldChunk entity index。
- [ ] spatial Harpoon 的 owner collision rule 已建立。
- [ ] Harpoon 回收时清除临时 collision rules。
- [ ] animation frame index 对当前 status 的 clip 有效。
- [ ] TODO: HP 和状态转换不变量。

## 当前限制与替代方案

- **Known limitation**：TODO
- **Alternative**：独立 Actor component/state machine。
- **Alternative**：event queue 分离 collision geometry 与 gameplay damage。
- **Alternative**：projectile pool 而不是每个 owner 固定一个 weapon entity。

## 如何验证

| 场景 | 验证方式 | 当前状态 |
|---|---|---|
| 按键优先级 | table test | TODO |
| 一帧跨过 attack threshold | scenario test | TODO |
| Harpoon 完整生命周期 | replay + state assertions | TODO |
| 同一 projectile 不重复伤害 | collision-rule test | TODO |

## 代码入口

- `game/player.odin` — Player 输入、运动意图和动画状态
- `game/shark.odin` — Shark/Harpoon 状态更新
- `game/game_init.odin` — Actor 和关系初始化
- `game/game.odin` — Actor 更新在一帧中的位置

## 相关文档

- [Entity](entity.md)
- [SimRegion](sim_region.md)
- [碰撞系统](collision.md)
- [碰撞规则](collision_rules.md)
- [图片与动画](draw_image_animation.md)

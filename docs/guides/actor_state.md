# Actor 状态更新

| 字段 | 内容 |
|---|---|
| Status | Draft（框架） |
| Code scope | `game/player.odin`、`game/shark.odin`、`game/entity.odin`、`game/game.odin` |
| Last verified | TODO |

> 本文讨论 Player、Shark 和 Harpoon 的玩法状态与更新顺序。Entity 的存储和引用模型见 [Entity](entity.md)，运动与碰撞见 [SimRegion](sim_region.md) 和[碰撞系统](collision.md)。

## 要解决的问题

1. 状态的切换逻辑：人物在Walk或者Idle时，如果突然Attack，需要优先进入Attack状态同时开始播放动画。反过来，Attack需要结束以后才能进入Idle或者Walk。
2. 每个状态内部需要知道自己的节律（什么时候结束，从开始到当前位置的节拍）
3. 特殊状态（比如投掷）的特殊逻辑（比如什么时候创建鱼叉）

## Actor、Entity 与 SimEntity 的关系

<!-- TODO: Actor 是概念还是独立类型？哪些状态直接存在 LowEntity？ -->

| 数据 | Player | Shark | Harpoon | 所属关注点 |
|---|---|---|---|---|
| position / dp / ddp | TODO | TODO | TODO | movement |
| status / animation time | TODO | TODO | TODO | state/render |
| owner / weapon | TODO | TODO | TODO | relationship |
| flight time / target | — | — | TODO | projectile |



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

为什么用non-spatial控制？每次创建新的harpoon还是用non-spatial=false来让他隐形？
每次新建需要销毁和回收entity，可能对性能的开销远大于用一个flag来控制

```text
stored non-spatial entity
  -> make spatial at release
  -> ballistic movement
  -> collision event/rules
  -> flight time expires 用时间控制射程：不论目标远近，投射的用时不变，倒算出手速度。
  -> become non-spatial
  -> clear collision rules
```

### Owner 与 Weapon 引用

## 时间与确定性

<!-- TODO: fixed dt、毫秒整数、f32 timer、animation time 和 replay。 -->
fixed_dt: 固定frame时间，方便消费函数的计算

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

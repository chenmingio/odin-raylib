# Pairwise Collision Rules

| 字段 | 内容 |
|---|---|
| Status | Draft（框架） |
| Code scope | `game/collision_rules.odin`、`game/collision.odin`、`game/shark.odin`、`game/sim_region.odin` |
| Last verified | TODO |

> 本文解释“两个特定 entity 是否应该碰撞”的策略状态。几何检测和移动响应见[碰撞系统](collision.md)。

## 要解决的问题

<!-- TODO: general type rule 为什么不足以表达 owner/projectile 和 hit-once？ -->

## 三层职责

| 层 | 问题 | 当前入口 |
|---|---|---|
| Geometry | 路径是否命中 shape？ | TODO |
| Policy | 这对 entity 是否允许碰撞？ | TODO |
| Gameplay response | 命中后阻挡、扣血还是穿过？ | TODO |

<!-- TODO: 解释把三层混在一起会造成什么维护问题。 -->

## 当前判定顺序

```text
same SimEntity?
  -> both collidable?
  -> both spatial?
  -> pairwise override exists?
  -> default allow
```

<!-- TODO: 按 can_collide 的真实代码核对和展开。 -->

## Rule 的身份与规范化

<!-- TODO: 为什么 `(a,b)` 和 `(b,a)` 是同一条 rule，为什么先 min/max。 -->

```text
(entity_a, entity_b)
  -> ordered pair (min, max)
  -> hash bucket
  -> chained lookup
```

## 存储、所有权与生命周期

| 数据 | 所有者 | 分配来源 | 释放/复用方式 |
|---|---|---|---|
| hash buckets | TODO | TODO | TODO |
| active rule | TODO | TODO | TODO |
| free rule | TODO | TODO | TODO |

### 为什么使用 hash chain + free list

<!-- TODO: 数量、创建/清除频率、arena 不支持单点 free。 -->

### Pointer-to-pointer 删除技巧

<!-- TODO: 解释 `link := &bucket` 为什么能统一删除链头和中间节点。配小图。 -->

## 当前用例

### Weapon 与 Owner

<!-- TODO: release 时创建什么 rule，何时删除。 -->

### Weapon 与 Player

<!-- TODO: 首次 hit 后为什么增加 false rule；为什么 collision response 不停止 projectile。 -->

### Projectile 回收

<!-- TODO: clear_collision_rules_for 如何避免下一次投掷继承旧状态。 -->

## Entity Index 复用风险

<!-- TODO: rule 保存裸 u32；如果 entity slot 复用但旧 rule 未清除，会发生什么？ -->

可比较：

| 引用方案 | 访问成本 | 失效检测 | 适用条件 |
|---|---|---|---|
| u32 storage index | TODO | TODO | 当前 |
| `{index, generation}` | TODO | TODO | TODO |
| stable entity ID | TODO | TODO | TODO |

## Non-stopping Collision 的后续路径

<!-- TODO: 当前 handle_collision 返回 false 后如何处理剩余位移；是否仍检测更远的墙。 -->

## 关键不变量

- [ ] pair 的顺序不影响查找结果。
- [ ] 同一 pair 最多存在一条 active rule。
- [ ] free-list 节点不同时出现在 active hash chain。
- [ ] entity 销毁或复用 index 前清理相关 rule。
- [ ] 临时 projectile 生命周期结束时清理相关 rule。

## 当前限制与替代方案

- **Known limitation**：TODO
- **Alternative**：由 owner 字段直接处理 owner/projectile 规则。
- **Alternative**：按 entity type 的 collision matrix。
- **Alternative**：collision event set 只在单帧内去重。
- **Alternative**：generational entity handles。

## 如何验证

| 场景 | 预期 | 验证方式 |
|---|---|---|
| add 同一 pair 两次 | 更新而非重复 | unit test |
| 反向查询 pair | 命中同一 rule | unit test |
| 删除 bucket 头/中/尾 | 链表保持有效 | unit test |
| clear entity 的多条 rule | 全部进入 free list | unit test |
| weapon 再次投掷 | 不继承旧 hit-once rule | scenario test |

## 代码入口

- `game/collision_rules.odin` — 存储、查找、增加和清除
- `game/collision.odin` — policy 查询和 gameplay response
- `game/shark.odin` — weapon-owner rule 创建
- `game/sim_region.odin` — projectile 回收和 rule 清理

## 相关文档

- [碰撞系统](collision.md)
- [Actor 状态](actor_state.md)
- [Entity](entity.md)
- [容器设计](container_design.md)

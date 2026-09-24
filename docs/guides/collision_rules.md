# Pairwise Collision Rules

## 要解决的问题

general type rule 不足以表达 owner/projectile 和 hit-once
- 武器（在spatial的时候）不能与主人碰撞（需要用owner_entity_id来代替判断吗？）
- 武器也不能和“敌人”碰撞
- 碰撞计算以帧为单位，会反复扣血。扣血的lifetime这里可以用碰撞检测控制 


## 当前判定顺序

优先寻找特殊规则
通用规则兜底


## Rule 的数据结构
- Rule数据在heap上分配，而不是固定数量的array
- State里的collision_rule_hash是256个rule-bucket，用hash作为idx使用
- 单层的bucket单链表，内含ety_a/b+rule
- 关键在于hash的设计：pairwise => a vs b或 b vs a,需要保存两遍？key用ety_min解决这个问题。可以认为min也是hash的一个步骤。

```text
(entity_a, entity_b)
  -> ordered pair (min, max)
  -> hash bucket
  -> chained lookup
```
### 难点：clear collision rule
一个 rule 不再需要时，不立即释放它的内存，而是把节点从原链表中摘除，再放入 free list，供后续复用。
摘除节点时，需要修改“指向当前节点的那个指针”：如果当前节点是头节点，就修改 state.collision_rule_hash[hash]；如果当前节点不是头节点，就修改前一个节点的 next。
为了统一处理这两种情况，遍历时让 link 保存“指针槽位的地址”。初始时，link = &state.collision_rule_hash[hash]；保留当前节点并继续遍历时，link 改为指向当前节点的 next 字段。
因此，link^ 始终是当前节点的指针。删除当前节点只需执行 link^ = rule.next，让这个槽位改为指向下一个节点。删除后 link 不变，因为同一个槽位现在已经指向下一个待检查的节点。


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


## 当前限制与替代方案

- **Known limitation**：TODO
- **Alternative**：由 owner 字段直接处理 owner/projectile 规则。
- **Alternative**：按 entity type 的 collision matrix。
- **Alternative**：collision event set 只在单帧内去重。
- **Alternative**：generational entity handles。

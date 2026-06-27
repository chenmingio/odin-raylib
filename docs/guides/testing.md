# 游戏开发中的轻量测试策略

**目的**：在不拖慢开发节奏的前提下，尽早发现复杂状态系统里的错误
**适用于**：world chunk、entity、sim region、collision、replay 等容易破坏不变量的代码
**前置条件**：了解 [world_chunk](world_chunk.md)、[entity](entity.md)、[sim_region](sim_region.md)

---

## 核心思路

游戏代码和 Web 业务代码不太一样。很多错误不是一次请求失败，而是世界状态悄悄坏掉：entity 在错误 chunk、block count 不对、index 重复、sim 回写漏字段、碰撞规则残留。

开发阶段不需要一开始就写大量 Web 风格的测试。更适合的策略是三层：

| 层级 | 用途 | 成本 | 适合检查什么 |
|---|---|---|---|
| **assert / validate** | 每帧或关键操作后抓坏状态 | 低 | 容器不变量、index 范围、链表结构 |
| **场景测试** | 固定输入下验证核心数据结构行为 | 中 | 插入、删除、跨 chunk 移动、begin/end sim |
| **可视化调试** | 观察空间关系和手感 | 中 | chunk 边界、碰撞体、entity id、相机范围 |

原则：

```
核心数据结构：assert + 少量场景测试
空间/移动/碰撞：可视化 debug
玩法/手感：手测 + replay
回归问题：遇到一次就补一个 assert 或小测试
```

---

## 一、先写不变量

在写测试前，先把数据结构的不变量写清楚。测试是验证工具，不变量才是设计本身。

以 `WorldChunk` / `WorldEntityBlock` 为例：

```text
只要 WorldChunk 存在，chunk.first_block != nil
每个 block 的 entity_count <= len(entity_indexes)
first_block 可以满；满不是错误，只表示下一次插入前要扩容
插入函数必须在写入前保证 first_block 有空位
删除后唯一空 block 保留，多余空 first_block 回收
chunk 里不能重复存同一个 entity_index
entity.pos.chunkXYZ 必须和它所在 chunk 一致
```

这些规则可以直接转成 debug assert。

```odin
assert(chunk.first_block != nil)
assert(block.entity_count <= len(block.entity_indexes))
assert(entity_index < state.entity_count)
```

如果某条规则现在还没实现，也应该先写在文档或注释里，避免后面写代码时靠记忆维护。

---

## 二、写 validate 函数

`validate_world` 这种函数不需要优雅，目标是尽早炸出来。

开发期可以在关键操作后调用：

- `add_entity` 后
- `remove_entity_index_from_hash_chunk` 后
- `reIndex` 后
- `end_sim` 后
- debug build 的每帧末尾

示例结构：

```odin
validate_world :: proc(state: ^GameState) {
    for bucket in state.world.chunk_hash {
        for chunk := bucket; chunk != nil; chunk = chunk.next_in_hash {
            assert(chunk.first_block != nil)

            for block := chunk.first_block; block != nil; block = block.next {
                assert(block.entity_count <= len(block.entity_indexes))

                for entity_index in block.entity_indexes[:block.entity_count] {
                    assert(entity_index < state.entity_count)
                    entity := &state.entities[entity_index]
                    assert(entity.pos.chunkXYZ == chunk.chunkXYZ)
                }
            }
        }
    }
}
```

可以先只检查最关键的几条，之后遇到 bug 再补。不要为了让 validate 完美而停止推进功能。

---

## 三、给核心容器写场景测试

场景测试不需要覆盖所有玩法，只测最容易破坏全局状态的底层操作。

`WorldChunk` / entity index 推荐覆盖：

| 场景 | 重点 |
|---|---|
| 插入 1 个 entity | chunk 创建、first block 创建、count 正确 |
| 插入 16 个 entity | block 正好填满时仍然合法 |
| 插入 17 个 entity | 新 block 创建、链表结构正确 |
| 删除 first block 里的 entity | 用 first block 最后一个 index 填洞 |
| 删除 overflow block 里的 entity | 跨 block 填洞后 count 正确 |
| 删除到 first block 空 | 唯一空 block 保留，额外空 block 回收 |
| entity 跨 chunk 移动 | old chunk remove + new chunk add |
| begin_sim | 从 chunk index 正确生成 high entity |
| end_sim | high entity 回写 low entity，并更新 chunk index |

这些测试数量不多，但可以保护最容易写错的地方。

测试命令：

```bash
odin test game
```

如果当前代码还没形成可测 API，可以先用 debug-only 的验证入口代替，等 `add/remove/reIndex` 稳定后再补正式测试。

---

## 四、用可视化调试补足测试

游戏空间问题很难全靠测试发现。很多时候直接画出来更快。

推荐的 debug overlay：

- 显示玩家 `chunkXYZ`
- 显示当前 chunk 的 entity count
- 绘制 chunk 边界
- 在 entity 旁边画 `storage index`
- 绘制 collision volume
- 绘制 sim region bounds / updatable bounds
- 按键输出当前 chunk 的 block 链表状态

这些信息不要做成正式 UI，只作为开发工具。目标是快速判断：

```text
entity 是否在正确 chunk
跨 chunk 时 index 有没有迁移
sim region 是否加载了正确范围
碰撞体和视觉位置是否一致
```

---

## 五、Replay 比大测试更适合玩法回归

对于输入驱动的游戏逻辑，replay 很适合做回归验证：

1. 录一段固定输入
2. 每次修改后回放
3. 比较关键状态或肉眼观察结果

适合 replay 检查的内容：

- 玩家移动是否一致
- 攻击/动画状态机是否一致
- 碰撞后位置是否合理
- camera 跟随是否稳定
- 跨 chunk 移动是否触发 reIndex

Replay 不替代底层容器测试，但很适合保护玩法流程。

---

## 六、什么时候补测试

不要为了“测试覆盖率”补测试。优先给这些地方加：

| 情况 | 应该补什么 |
|---|---|
| 写了新的容器结构 | validate 函数 + 2 到 3 个场景测试 |
| 修了一个难定位的 bug | 一个复现这个 bug 的小测试或 assert |
| 涉及 index / pointer / freelist | assert + 场景测试 |
| 涉及空间迁移 | 可视化 debug + 场景测试 |
| 涉及手感 | replay + 手测 |

经验规则：

```text
代码越底层，越适合自动测试。
代码越空间化，越需要可视化调试。
代码越偏玩法手感，越依赖 replay 和手测。
```

---

## 当前项目的推荐落地顺序

1. 给 `WorldChunk` / `WorldEntityBlock` 写 `validate_world(state)`。
2. 在 `add_entity_index_to_hash_chunk`、`remove_entity_index_from_hash_chunk`、`reIndex` 后调用 validate。
3. 加 debug overlay：玩家 chunk、entity storage index、chunk 边界。
4. 等 `reIndex` 完成后，补 5 到 8 个 `odin test game` 场景测试。
5. 用现有输入录制/回放机制做一段跨 chunk 移动 replay。

先把“世界状态不能坏”守住，再追求更细的测试覆盖。

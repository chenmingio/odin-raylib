# WorldChunk 空间索引

**目的**：按空间区块索引 entity，支持高效的区域查询和模拟
**适用于**：理解游戏世界的空间分区和 entity 管理机制
**前置条件**：了解 WorldPosition（chunk + offset）坐标系统

---

## 动机

### 为什么需要chunk？

游戏里，Entity 的提取是按空间的，而不是简单遍历全部 entity。所以需要渲染或模拟某个区域时，先找到覆盖的 chunk，再从中提取 entity。

| 场景 | 不用 chunk | 用 chunk |
|------|-----------|---------|
| 渲染 | 遍历全部 10000 个 entity | 只查相关 chunk 里的 entity |
| 模拟 | 全量计算 | 只模拟相关区域的 entity |
| 移动 | 无需更新索引 | 跨 chunk 时需更新索引 |

```
World
├── ChunkHash[4096]         ← 固定 bucket 数组
│   ├── bucket[0] → Chunk(0,0,0) → Chunk(...)  ← 同 bucket 链表
│   ├── bucket[1] → nil
│   ├── bucket[2] → Chunk(1,0,0)
│   └── ...
└── FirstFree               ← 空闲 block 回收链表
```

### Chunk需要覆盖多大的地图空间？

| 太大 | 太小 |
|------|------|
| 每个 chunk 内 entity 太多，模拟开销大 | chunk 边界频繁跨越，索引更新频繁 |

当前值：`chunkSideInMeters :: 30`，解决屏幕尺寸

---

## 结构

### Chunk本身存array里（和entity一样）还是动态分配？entity为什么要存array里？
Entity：每帧批量遍历 entities[0..count]，连续内存让 CPU可以预取后续数据，所以需要数组保证连续。

Chunk：永远是通过 hash 单个查找，拿到一个 chunk 处理完就完了，不存在"遍历所有 chunk"的场景。既然每次只访问一个，连不连续无所谓，动态分配更简单——不用预估上限，用多少分多少。

### Chunk的结构如何设计？

方案1:用xyz三位数组储存所有chunk。缺点：大部分chunk都是空的。
方案2:动态分配chunk以后，用 hash map来索引。

### hashmap的各种变体

方案1： 使用odin的map，用xyz当key。问题：Odin 的 `map` 会自动扩容，破坏 arena 内存布局
方案2： 用手动管理的固定 bucket + 链表。

### map的value里放什么？
方案1: chunk的值（包含了下一个chunk的指针）

比如Casey 的 C 代码中 `chunk_hash[4096]` 直接存 `world_chunk` 结构体（inline），大部分 bucket 只有一个 chunk，避免一次指针跳转。由于是inline的value，无法表示nil，没有分配的bucket，就需要用 `ChunkX == TILE_CHUNK_UNINITIALIZED`

方案2: 放chunk的指针
Odin 中选择存 `^WorldChunk` 指针：
- Odin 没有 C 的"未初始化哨兵"惯用法（`ChunkX == TILE_CHUNK_UNINITIALIZED`）
- `Maybe` 会让结构体过大
- 指针为 `nil` 即表示空 bucket，语义清晰

### chunk里怎么储存entity？
方案1. 使用entity引用链表，不实用block中间容器。问题：缓存命中差。16个node的地址可能在不同的缓存块里，需要多次读取缓存。相反利用block来强制他们在一个缓存块里，速度快100倍。
方案2. 使用block（unrolled linked list）来储存16个entity地址。
方案3. 存entity的index，而不是地址。entities是固定长度列表，所以可以用index来索引。chunk这种动态分配的就不行。

| 方式 | 优点 | 缺点 |
|------|------|------|
| **地址（指针）** | 直接访问，零开销 | entity 移动时需通知所有引用者 |
| **Id 索引** | entity 移动不影响引用 | 需要一次间接查找 |

方案4: 追加一个generation field，该机制用于去中心化引用的失效检测（id + generation）。比如多个模块引用了entity，然后entity消失了，他们的引用失效了。但我不想中心化通知每个模块，就用一个版本号来管理。 

当前 chunk 的 entity index 是中心化管理的，暂不需要 generation。

当前方案：block 中存 entity 的**数组索引**（u32），不存指针。

### 数据结构

```odin
WorldEntityBlock :: struct {
    entity_count: u32,
    entity_index: [16]u32,          // 每 block 最多 16 个 entity 索引
    next:         ^WorldEntityBlock, // 溢出时链接下一个 block
}

WorldChunk :: struct {
    first_block:  ^WorldEntityBlock,  // 该 chunk 内的 entity block 链表
    next_in_hash: ^WorldChunk,        // 同一 bucket 内的下一个 chunk
    chunkXYZ:     V3i,
}

World :: struct {
    chunk_dim_in_meters: V3i,
    chunk_hash:          [4096]^WorldChunk,  // 固定 bucket 数组
    first_free:          ^WorldEntityBlock,  // 空闲 block 回收链表
}
```

### 为什么 Chunk 和 Entity 用不同的存储方式？

| | WorldChunk | WorldEntityBlock |
|------|-----------|-----------------|
| **访问模式** | 按 XYZ 跳跃查找 | 批量/连续遍历 |
| **链表粒度** | 一个 chunk 一个节点 | 16 个 entity 一个节点 |
| **原因** | chunk 是容器，数量少，跳跃查找 OK | entity 数量多，16 个一组提高缓存命中 |


### 关系图

```
World
├── chunk_hash[4096]
│   └── [h] → WorldChunk → WorldChunk → nil   (next_in_hash 链表)
│                 │
│             first_block
│                 │
│             WorldEntityBlock [16个entity索引]
│                 │ next
│             WorldEntityBlock [16个entity索引]
│                 │ next
│                nil
└── first_free → WorldEntityBlock → WorldEntityBlock → nil  (回收链表)
```

### Hash 函数

```odin
hashChunk :: proc(xyz: V3i) -> i32 {
    return xyz.x * 19 + xyz.y * 7 + xyz.z * 3
}
// bucket = hash & (4096 - 1)
```

查找/创建 chunk：遍历 bucket 链表，找到匹配的返回；未找到则在 arena 上分配新 chunk 插入头部。参考 `GetWorldChunk()`（handmade_world.cpp:66-113）。

---

## 流程

### add entity（初始化时）

```
1. entity 存入 GameState.entities[] 数组
2. 根据 entity.pos.chunkXYZ 找到（或创建）chunk
3. 在 chunk 的 first_block 中插入 entity 索引
4. block 满 16 个 → 从 first_free 取空闲 block，或分配新 block
```

参考 `ChangeEntityLocationRaw()` 的 NewP 分支（handmade_world.cpp:256-281）。

### load entities（渲染/模拟时）

```
1. 计算模拟区域覆盖的 chunk 范围（min_chunk → max_chunk）
2. 三层循环遍历范围内所有 chunk
3. 对每个 chunk，遍历 entity block 链表
4. 提取所有 entity 索引，加载到 sim region
```

参考 `BeginSim()`（handmade_sim_region.cpp:154-228）。

### remove / move entity（模拟时）

| 操作 | 步骤 |
|------|------|
| **remove** | 在 block 中找到 entity 索引 → 用最后一个索引覆盖 → count-- → 空 block 回收到 first_free |
| **move（跨 chunk）** | remove from old chunk + add to new chunk |
| **move（同 chunk）** | 无需更新索引 |

跨 chunk 的判断依赖 `canonicalize`：entity 移动后 offset 超出 chunk 边界时，重新归位到正确的 chunk。

参考 `ChangeEntityLocationRaw()` 的 OldP 分支（handmade_world.cpp:218-253）。

---

## 参见

- [Handmade Hero Day 095 源码](../../../handmade-hero/handmade_hero_day_095_source/code/) — `handmade_world.h/cpp`, `handmade_sim_region.h/cpp`
- `game/world.odin` — 当前 Odin 实现
- `game/entity.odin` — Entity 定义和 add/remove 操作

---

**最后更新**: 2026-02-11

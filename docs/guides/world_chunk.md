# WorldChunk 空间索引

**目的**：按空间区块索引 entity，支持高效的区域查询和模拟
**适用于**：理解游戏世界的空间分区和 entity 管理机制
**前置条件**：了解 WorldPosition（chunk + offset）坐标系统

---

## 快速开始

Entity 的提取是按空间区块（chunk）组织的。需要渲染或模拟某个区域时，先找到覆盖的 chunk，再从中提取 entity——而不是遍历全部 entity。

```
World
├── ChunkHash[4096]         ← 固定 bucket 数组
│   ├── bucket[0] → Chunk(0,0,0) → Chunk(...)  ← 同 bucket 链表
│   ├── bucket[1] → nil
│   ├── bucket[2] → Chunk(1,0,0)
│   └── ...
└── FirstFree               ← 空闲 block 回收链表
```

---

## 核心概念

### 为什么用 chunk

| 场景 | 不用 chunk | 用 chunk |
|------|-----------|---------|
| 渲染 | 遍历全部 10000 个 entity | 只查相关 chunk 里的 entity |
| 模拟 | 全量计算 | 只模拟相关区域的 entity |
| 移动 | 无需更新索引 | 跨 chunk 时需更新索引 |

### 为什么不用 Odin map

Chunk 分配在 permanent arena 上，而 Odin 的 `map` 会自动扩容，会破坏 arena 内存布局或浪费空间。所以用手动管理的固定 bucket + 链表。

### Chunk 大小选择

| 太大 | 太小 |
|------|------|
| 每个 chunk 内 entity 太多，模拟开销大 | chunk 边界频繁跨越，索引更新频繁 |

当前值：`chunkSideInMeters :: 30`

---

## 数据结构

### WorldPosition

```odin
WorldPosition :: struct {
    chunkXYZ: V3i,   // 所在 chunk 的坐标
    offset:   V3,    // chunk 内的偏移（米）
}
```

### WorldEntityBlock — entity 的容器

```odin
WorldEntityBlock :: struct {
    entity_count: u32,
    entity_index: [16]u32,          // 每 block 最多 16 个 entity 索引
    next:         ^WorldEntityBlock, // 溢出时链接下一个 block
}
```

### WorldChunk — chunk 本身

```odin
WorldChunk :: struct {
    first_block:  ^WorldEntityBlock,  // 该 chunk 内的 entity block 链表
    next_in_hash: ^WorldChunk,        // 同一 bucket 内的下一个 chunk
    chunkXYZ:     V3i,
}
```

### World — 全局容器

```odin
World :: struct {
    chunk_dim_in_meters: V3i,
    chunk_hash:          [4096]^WorldChunk,  // 固定 bucket 数组
    first_free:          ^WorldEntityBlock,  // 空闲 block 回收链表
}
```

### 结构关系

```
chunk_hash[h] → WorldChunk → WorldChunk → nil   (next_in_hash 链表)
                    │
                first_block
                    │
                WorldEntityBlock [16个entity索引]
                    │ next
                WorldEntityBlock [16个entity索引]
                    │ next
                   nil
```

---

## 储存与索引

### Hash 函数

```odin
hashChunk :: proc(xyz: V3i) -> i32 {
    return xyz.x * 19 + xyz.y * 7 + xyz.z * 3
}
// bucket = hash & (4096 - 1)
```

### 查找/创建 chunk

```odin
get_world_chunk :: proc(state: ^GameState, chunkXYZ: V3i, memory: Memory) -> ^WorldChunk {
    h := hashChunk(chunkXYZ)
    // 遍历链表查找匹配的 chunk
    // 找到 → 返回
    // 未找到 → 在 arena 上分配新 chunk，插入 bucket 头部
}
```

参考 Handmade Hero `GetWorldChunk()`（handmade_world.cpp:66-113）。

---

## 操作流程

### 初始化 — add entity

```
1. entity 存入 GameState.entities[] 数组
2. 根据 entity.pos.chunkXYZ 找到（或创建）chunk
3. 在 chunk 的 first_block 中插入 entity 索引
4. block 满 16 个 → 从 first_free 取空闲 block，或分配新 block
```

参考 Handmade Hero `ChangeEntityLocationRaw()` 的 NewP 分支（handmade_world.cpp:256-281）。

### 渲染/模拟 — load entities

```
1. 计算模拟区域覆盖的 chunk 范围（min_chunk → max_chunk）
2. 三层循环遍历范围内所有 chunk
3. 对每个 chunk，遍历 entity block 链表
4. 提取所有 entity 索引，加载到 sim region
```

参考 Handmade Hero `BeginSim()`（handmade_sim_region.cpp:154-228）。

### 模拟 — remove / move entity

| 操作 | 步骤 |
|------|------|
| **remove** | 在 block 中找到 entity 索引 → 用最后一个索引覆盖 → count-- → 空 block 回收到 first_free |
| **move（跨 chunk）** | remove from old chunk + add to new chunk |
| **move（同 chunk）** | 无需更新索引 |

参考 Handmade Hero `ChangeEntityLocationRaw()` 的 OldP 分支（handmade_world.cpp:218-253）。

---

## 设计决策

### Chunk 链表 vs Entity Block 的存储方式

| | WorldChunk | WorldEntityBlock |
|------|-----------|-----------------|
| **访问模式** | 按 XYZ 跳跃查找 | 批量/连续遍历 |
| **链表粒度** | 一个 chunk 一个节点 | 16 个 entity 一个节点 |
| **原因** | chunk 是容器，数量少，跳跃查找 OK | entity 数量多，16 个一组提高缓存命中 |

### 地址 vs Id 索引

| 方式 | 优点 | 缺点 |
|------|------|------|
| **地址（指针）** | 直接访问，零开销 | entity 移动时需通知所有引用者 |
| **Id 索引** | entity 移动不影响引用 | 需要一次间接查找 |

当前方案：block 中存 entity 的**数组索引**（u32），不存指针。

**generation 机制**：用于去中心化引用的失效检测（id + generation）。当前 chunk 的 entity index 是中心化管理的，暂不需要 generation。

### Casey 的 inline 模式 vs Odin 指针模式

Casey 的 C 代码中，`chunk_hash[4096]` 直接存 `world_chunk` 结构体（inline），因为大部分 bucket 只有一个 chunk，避免了一次指针跳转。

Odin 中选择存 `^WorldChunk` 指针，原因：
- Odin 没有 C 的"未初始化哨兵"惯用法（`ChunkX == TILE_CHUNK_UNINITIALIZED`）
- 用 `Maybe` 会让结构体过大
- 指针为 `nil` 即表示空 bucket，语义清晰

---

## 参见

- [Handmade Hero Day 095 源码](../../../handmade-hero/handmade_hero_day_095_source/code/) — `handmade_world.h/cpp`, `handmade_sim_region.h/cpp`
- `game/world.odin` — 当前 Odin 实现
- `game/entity.odin` — Entity 定义和 add/remove 操作

---

**最后更新**: 2026-02-11

# WorldChunk 空间索引

**目的**：按空间区块索引 entity，支持高效的区域查询和模拟
**适用于**：理解游戏世界的空间分区和 entity 管理机制
**前置条件**：了解 WorldPosition（chunk + offset）坐标系统

---

## 概览

### 为什么需要 chunk？

游戏里 entity 的提取是按空间的，而不是简单遍历全部 entity。渲染或模拟某个区域时，先找到覆盖的 chunk，再从中提取 entity。

| 场景 | 不用 chunk | 用 chunk |
|------|-----------|---------|
| 渲染 | 遍历全部 10000 个 entity | 只查相关 chunk 里的 entity |
| 模拟 | 全量计算 | 只模拟相关区域的 entity |
| 移动 | 无需更新索引 | 跨 chunk 时需更新索引 |

### 数据结构

```odin
WorldEntityBlock :: struct {
    entity_count: u32,
    entity_index: [16]u32,            // 每 block 最多 16 个 entity 索引
    next:         ^WorldEntityBlock,  // 溢出时链接下一个 block
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

### 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| `chunkSideInMeters` | 30 | 大约覆盖一个屏幕；过大→单 chunk entity 太多，过小→跨 chunk 频繁 |
| `chunk_hash` bucket 数 | 4096 | 2 的幂，可用 `& (4096-1)` 快速取模 |
| 每 block entity 数 | 16 | `16 × 4 字节 = 64 字节`，正好一个 cache line |

---

## 流程

### add entity（初始化时）

```
1. entity 存入 GameState.entities[] 数组
2. 根据 entity.pos.chunkXYZ 找到（或创建）chunk
3. 在 chunk 的 first_block 中插入 entity 索引
4. block 满 16 个 → 从 first_free 取空闲 block，或在 arena 上分配新 block
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

### 查找/创建 chunk

```odin
hashChunk :: proc(xyz: V3i) -> i32 {
    return xyz.x * 19 + xyz.y * 7 + xyz.z * 3
}
// bucket = hash & (4096 - 1)
```

遍历 bucket 链表，找到匹配的返回；未找到则在 arena 上分配新 chunk 插入头部。参考 `GetWorldChunk()`（handmade_world.cpp:66-113）。

### first_free 的回收时机

remove entity 后若 block 空了，**整个 block 摘出来挂到 `first_free` 链表头部**；下次需要新 block 时优先从 `first_free` 取，取不到再向 arena 申请。

> 为什么不直接释放？arena 是 bump allocator，不支持单点释放，所以用 free list 复用。

---

## 设计决策

### 决策 1：Chunk 用 hash map，不用 3D 数组

**选择**：动态分配 chunk + hash map 索引

**备选**：
- A. 用 `[X][Y][Z]Chunk` 三维数组储存所有 chunk

**理由**：
- A 的问题：地图无限大，大部分 chunk 是空的，浪费内存
- 动态分配：用多少分多少
- chunk 的访问模式是"按 XYZ 跳跃查找单个"，不需要连续内存

### 决策 2：手动 hash，不用 Odin 的 map

**选择**：固定 bucket 数组 `[4096]^WorldChunk` + 链表

**备选**：
- A. 用 Odin 的 `map[V3i]^WorldChunk`

**理由**：
- A 的问题：Odin 的 `map` 会自动扩容，破坏 arena 内存布局
- 手动 hash：bucket 数固定，节点都在 arena 上，内存布局可控

### 决策 3：bucket 存 `^WorldChunk` 指针，不存本体

**选择**：`chunk_hash: [4096]^WorldChunk`

**备选**：
- A. Casey 的 C 代码：`chunk_hash: [4096]WorldChunk`（inline 存本体）

**理由**：
- A 的优点：大部分 bucket 只有一个 chunk，省一次指针跳转
- A 的问题：inline 没法表示"空 bucket"，需要哨兵值（`ChunkX == TILE_CHUNK_UNINITIALIZED`）
- Odin 没有 C 的哨兵惯用法；用 `Maybe` 会让结构体过大
- 存指针：`nil` 即空 bucket，语义清晰

### 决策 4：block 存 entity index，不存本体或指针

**选择**：block 存 `[16]u32` 索引，entity 本体放 `GameState.entities[]` 数组

**备选**：
- A. block 直接存 entity 本体
- B. block 存 `^Entity` 指针

**理由**：
- A 的问题：
  - 移动 entity = 拷贝整个 struct（几百字节 vs 4 字节）
  - 引用不稳定（block 重分配后地址变）
  - 全局遍历不友好（数据散落在各 chunk 的 block 里）
  - 内存浪费（半空 block 浪费几百字节 × 16）
- B 的问题：block 节点动态分配，entity 跨 chunk 移动后指针失效
- 选 index：
  - entity 本体在 `entities[]` 连续内存，cache 友好
  - index 是 u32（4 字节），移动便宜
  - 数组 index 稳定，引用不失效

### 决策 5：block 用 unrolled linked list（16 个一组）

**选择**：每个 block 装 16 个 entity index，溢出时链接下一个 block

**备选**：
- A. 普通链表（每个节点一个 entity index）

**理由**：
- A 的问题：链表节点散落在堆上，遍历时每读一个就要跳一次缓存
- unrolled list：
  - `16 × 4 字节 = 64 字节`，**正好一个 cache line**
  - 一次缓存读拿到 16 个 index
  - 16 满了再走 `next` 跳一次缓存
- Casey 实测：相比普通链表快约 100 倍

### 决策 6：暂不引入 generation 字段

**选择**：block 只存 `u32` index，不带 generation

**备选**：
- A. 存 `{id, generation}`，访问时校验 generation 是否匹配

**理由**：
- generation 用于**去中心化的引用失效检测**：多个模块各自持有 entity 引用，entity 死了不需要中心化通知每个模块，下次访问检查 generation 自动发现失效
- 当前 chunk 的 entity index 是**中心化管理**的（chunk 知道自己持有哪些 entity，entity 死了 chunk 主动移除）
- 如果未来出现"多个模块各自缓存 entity 引用"的场景，再引入 generation

### 决策 7：Chunk 和 EntityBlock 用不同的链表粒度

**选择**：chunk 一个节点一个；entity block 一个节点 16 个

**理由**：

| | WorldChunk | WorldEntityBlock |
|------|-----------|-----------------|
| **访问模式** | 按 XYZ 跳跃查找单个 | 批量/连续遍历 |
| **链表粒度** | 一个 chunk 一个节点 | 16 个 entity 一个节点 |
| **为什么** | 数量少，跳跃访问，连续无意义 | 数量多，批量遍历，要缓存命中 |

---

## 参见

- [Handmade Hero Day 095 源码](../../../handmade-hero/handmade_hero_day_095_source/code/) — `handmade_world.h/cpp`, `handmade_sim_region.h/cpp`
- `game/world.odin` — 当前 Odin 实现
- `game/entity.odin` — Entity 定义和 add/remove 操作

---

**最后更新**: 2026-06-04

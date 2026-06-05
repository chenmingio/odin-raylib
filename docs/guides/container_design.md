# 容器设计的反复出现的权衡

**目的**：把项目里多个层级的"容器"放到一起，抽出反复出现的设计问题和权衡轴
**适用于**：设计新容器（inventory、quest log、网络队列…）时作为 checklist
**前置条件**：读过 [world_chunk](world_chunk.md)、[store_vs_index](store_vs_index.md)、[data_lifetime](data_lifetime.md)、[game_memory](game_memory.md)、[data_structure](data_structure.md)

---

## 概览

项目里"容器"概念至少出现在 6 个层级，每一层都在解同样几类问题：数据存哪、怎么找、怎么创建/删除、谁出内存、引用稳不稳、cache 友不友好。把这些层并排看，权衡的主线就显出来了。

---

## 一、项目里的对象 vs 容器

每个"对象"都需要找一个"容器"来装，容器本身可能又被另一个容器装。这个项目里的对应关系：

| 对象 | 装它的容器 | 代码位置 |
|---|---|---|
| **原始字节** | `permanent_storage` / `temporary_storage` Arena（启动时从堆 malloc 一大块） | `main.odin` |
| **LowEntity** | `GameState.entities[10000]` 定长数组里 inline 存 | `game.odin:62` |
| **WorldChunk** | `World.chunk_hash[4096]` hash 桶 + bucket 内链表 | `world.odin:21` |
| **entity index（u32）** | `WorldEntityBlock.entity_indexes[16]` + block 链 | `world.odin:8` |
| **WorldEntityBlock** | 同一个节点对象，两种状态：**active** 时挂在 `WorldChunk.first_block` 链；**空闲**时挂在 `World.first_free` 链 | `world.odin:8, 25` |
| **HighEntity** | `SimRegion.high_entities[4096]` 定长数组里 inline 存 | `sim_region.odin:6` |

> 注：`WorldEntityBlock` 只有一种类型。"空闲 block"不是另一个对象，而是同一个节点 `next` 指针指向 `first_free` 链头时的"待复用"状态。删除时 block 从 chunk 链摘下、挂到 free 链；下次需要新 block 时从 free 链头 pop 回 chunk 链。

它们形成一条依赖链：

```
Arena 提供原始字节
 ├── GameState.entities[] 装 LowEntity 本体（权威数据 source of truth）
 ├── chunk_hash[] 装 WorldChunk（空间索引）
 │    └── WorldChunk.first_block 链 装 WorldEntityBlock
 │         ├── block 里装 entity index (u32)，指回 entities[]
 │         └── block 变空 → 摘下挂到 World.first_free，等待复用
 └── SimRegion.high_entities[] 装 HighEntity（每帧从 entities[] + chunk 重建）
```

---

## 二、每层都要回答的 8 个问题

把 `store_vs_index.md` 里的 6 条真理 + `data_structure.md` 的选择框架合并，每个容器都在权衡这 8 件事：

| 问题 | 含义 | 项目里的典型对立选项 |
|---|---|---|
| **① 本体存哪** | storage 在哪 | 容器内 inline vs 外部 array vs 堆 |
| **② 怎么找到** | lookup 机制 | 数组下标 / hash / 链表扫描 |
| **③ 怎么创建** | 分配策略 | 预分配定长 / arena bump / pool 复用 |
| **④ 怎么删除** | 回收策略 | swap-and-pop / free list / 不删 |
| **⑤ 容量上限** | 静态/动态 | 固定数组 / 链表无限扩 |
| **⑥ 内存来源** | 谁拨地 | 全局静态 / perm arena / temp arena / pool |
| **⑦ 引用稳不稳** | 引用是否会失效 | 指针 / index / handle(gen) |
| **⑧ 访问模式** | 谁来读 | 随机点查 / 批量顺序遍历 |

下面按对象逐个过一遍。每节给出 8 字段答案 + 一段代码 + "如果不这样做会怎样"的反事实推理。

---

### LowEntity

- **本体存哪**：`GameState.entities[10000]` 定长数组里 inline 存
- **怎么查找**：u32 下标直接索引
- **怎么创建**：`entities[count] = e; count++` 追加到末尾
- **怎么删除**：swap-and-pop（最后一个覆盖到空位）
- **容量上限**：编译期固定 10000
- **内存来源**：perm arena 里的 `GameState`
- **引用稳不稳**：数组位置稳定（不 realloc）；但 swap-and-pop 删除会让被搬走的 entity 的 index 改变 ⚠️（当前未处理，见 [entity.md](entity.md)）
- **访问模式**：偶尔点查（如 player）+ 批量遍历（渲染/模拟）

**代码**（`game/entity.odin`、`game/game.odin`）：
```odin
GameState :: struct {
    entities:     [10000]LowEntity,
    entity_count: u32,
    ...
}

add_entity :: proc(state: ^GameState, entity: LowEntity, memory: ^Memory) {
    assert(state.entity_count < len(state.entities))
    state.entities[state.entity_count] = entity
    state.entity_count += 1
    ...
}

remove_entity :: proc(state: ^GameState, index: u32) {
    state.entities[index] = state.entities[state.entity_count - 1]
    state.entity_count -= 1
}
```

**反事实：如果不这样存？**

| 备选方案 | 会出什么问题 |
|---|---|
| 每个 entity 各自 `new(LowEntity, perm_alloc)` | 散落在 arena 各处，无法批量顺序遍历；cache 友好性差 |
| 改用 `[dynamic]LowEntity` 动态数组 | realloc 时整块挪位置，外部 `^LowEntity` 全部失效；与 arena 模型冲突 |
| 直接把本体存到 WorldChunk 的 block 里（不分离 storage / index） | 跨 chunk 移动 = 拷贝整个 struct（几百字节 vs 4 字节 index）；全局遍历变成"遍历所有 chunk 的所有 block"；半空 block 浪费几百字节 |

---

### WorldChunk

- **本体存哪**：perm arena 上独立分配的节点；hash 桶 `chunk_hash[4096]` 只存 `^WorldChunk` 指针
- **怎么查找**：`hash(XYZ) & 4095` 得 bucket，沿 `next_in_hash` 链扫描匹配 XYZ
- **怎么创建**：找不到时 `new(WorldChunk, perm_alloc)`，头插到 bucket
- **怎么删除**：当前不删（地图只增不减）
- **容量上限**：bucket 数 4096 固定（2 的幂便于位运算）；chunk 总数无限
- **内存来源**：perm arena
- **引用稳不稳**：指针稳定（arena 不挪、不复制节点）
- **访问模式**：按 XYZ 跳跃点查；数量少、不需要连续内存

**代码**（`game/world.odin`）：
```odin
World :: struct {
    chunk_hash: [4096]^WorldChunk,   // 桶数组，nil = 空桶
    first_free: ^WorldEntityBlock,
    ...
}

WorldChunk :: struct {
    first_block:  ^WorldEntityBlock,
    next_in_hash: ^WorldChunk,       // 同 bucket 内下一个 chunk
    chunkXYZ:     V3i,
}

get_world_chunk :: proc(state: ^GameState, chunkXYZ: V3i, memory: Maybe(^Memory) = nil) -> ^WorldChunk {
    h := hashChunk(chunkXYZ)
    for c := state.world.chunk_hash[h]; c != nil; c = c.next_in_hash {
        if c.chunkXYZ == chunkXYZ { return c }
    }
    // 未找到 → 创建并头插
    new_chunk := new(WorldChunk, mem.perm_alloc)
    new_chunk.next_in_hash = state.world.chunk_hash[h]
    state.world.chunk_hash[h] = new_chunk
    return new_chunk
}
```

**反事实：如果不这样存？**

| 备选方案 | 会出什么问题 |
|---|---|
| 用 `[X][Y][Z]WorldChunk` 三维数组 | 地图无限大，大部分 chunk 是空的，内存浪费爆炸（见 `world_chunk.md` 决策 1） |
| 用 Odin 内建 `map[V3i]^WorldChunk` | map 自动 rehash/realloc，破坏 arena 内存布局；无法控制节点何时分配（决策 2） |
| `chunk_hash[4096]WorldChunk` inline 存本体（Casey C 写法） | 没法表达"空 bucket"——Odin 没有 C 的哨兵惯用法（`ChunkX == UNINITIALIZED`）；用 `Maybe` 又让结构体变大（决策 3） |
| 完全不要 chunk 这一层，直接在 entities[] 上做空间查询 | 渲染/模拟时 O(n) 扫全部 10000 个 entity 判断"在不在屏幕里" |

---

### entity index (u32)

- **本体存哪**：`WorldEntityBlock.entity_indexes[16]` 数组里 inline 存
- **怎么查找**：从 `chunk.first_block` 顺 `.next` 遍历整条 block 链
- **怎么创建**：当前 block 未满 → 直接写；满了 → 新建 block 接到链尾
- **怎么删除**：swap-and-pop；block 空了把整个 block 摘到 free list
- **容量上限**：每节点 16；block 链无限增长
- **内存来源**：perm arena（首次分配）/ free list（复用）
- **引用稳不稳**：u32 值稳定，但 entity 在哪个 block / 哪个槽位会变（每次 swap-and-pop 后）
- **访问模式**：批量顺序遍历，要 cache 友好

**代码**（`game/entity.odin` 插入端、`game/sim_region.odin` 遍历端）：
```odin
WorldEntityBlock :: struct {
    entity_indexes: [16]u32,         // 16 × 4 字节 = 64 字节 = 一个 cache line
    entity_count:   u32,
    next:           ^WorldEntityBlock,
}

// 插入（add_entity 中）
chunk := get_world_chunk(state, entity.pos.chunkXYZ, memory)
block := chunk.first_block
for block.next != nil { block = block.next }
// ... 满了就 new 新 block，否则在当前 block 找空槽
```

```odin
// 遍历（begin_sim 中）
for block := chunk.first_block; block != nil; block = block.next {
    for entity_id in block.entity_indexes[:block.entity_count] {
        low_entity := &state.entities[entity_id]
        // ...
    }
}
```

**反事实：如果不这样存？**

| 备选方案 | 会出什么问题 |
|---|---|
| block 里直接存 `LowEntity` 本体 | 移动 entity = 跨 chunk 拷整个 struct；引用不稳；全局遍历困难；半空 block 浪费几百字节 × 16 |
| block 里存 `^LowEntity` 指针 | entities[] swap-and-pop 时被移走的 entity 地址变了，指针失效（其实 u32 也有同样问题，但 u32 至少不会"指错"，只会"指空"） |
| 带 generation 的 handle `{id, gen}` | 当前 chunk-entity 是中心化管理（chunk 知道自己装了谁，entity 死了 chunk 主动移除），不需要去中心化的失效检测（见 `world_chunk.md` 决策 6） |
| 把 u32 改成 u16 / u8 省空间 | 一个 cache line 能装更多 index，但 entity 总数受限；当前 u32 + 16 个正好 64 字节，刚刚好 |

---

### WorldEntityBlock

- **本体存哪**：perm arena 上独立分配；通过两条链复用同一片内存
  - **active 状态**：节点挂在某个 `WorldChunk.first_block` 链上
  - **空闲状态**：节点挂在 `World.first_free` 链上等待复用
- **怎么查找**：通常顺着 chunk 链遍历；free list 只在 pop 时用
- **怎么创建**：优先从 `first_free` 头部取，取不到才 `new` 申请
- **怎么删除**：entity 删完导致 block 空 → 从 chunk 链摘下，LIFO 头插到 `first_free`
- **容量上限**：无限
- **内存来源**：perm arena（首次）→ 之后永远复用
- **引用稳不稳**：节点地址稳定；但"哪条链上"会变
- **访问模式**：active 时被批量顺序遍历；free 时只做单点 pop

**代码**（free list 的复用模式，见 `world_chunk.md` "first_free 的回收时机"）：
```odin
World :: struct {
    chunk_hash: [4096]^WorldChunk,
    first_free: ^WorldEntityBlock,   // 空闲节点链头
}

// 分配（伪代码，目前 add_entity 还没走 free list）
alloc_block :: proc(world: ^World, memory: ^Memory) -> ^WorldEntityBlock {
    if world.first_free != nil {
        b := world.first_free
        world.first_free = b.next
        b^ = {}                          // 清零
        return b
    }
    return new(WorldEntityBlock, memory.perm_alloc)
}

// 回收：block 变空时
free_block :: proc(world: ^World, b: ^WorldEntityBlock) {
    b.next = world.first_free
    world.first_free = b
}
```

**反事实：如果不这样设计？**

| 备选方案 | 会出什么问题 |
|---|---|
| 一个 block 只装 1 个 entity index（普通链表） | 节点散落在 arena 各处，遍历每读一个就 cache miss 一次；Casey 实测比 unrolled list 慢约 100 倍 |
| 一个 block 装 1000 个 entity index | 大部分 chunk 没那么多 entity，半空 block 浪费严重；丢失 cache line 边界对齐的好处 |
| 不要 free list，删完直接弃节点 | arena 是 bump allocator 不支持单点释放，旧节点永远占地；地图 entity 数量波动时内存只增不减 |
| 用 malloc/free 代替 free list | 每次增删 entity 都走系统分配器，慢且碎片化；失去 arena 的批量释放优势 |

---

### HighEntity

- **本体存哪**：`SimRegion.high_entities[4096]` 定长数组 inline 存（含 `^LowEntity` 反指）
- **怎么查找**：u32 下标
- **怎么创建**：`begin_sim` 一次性从相关 chunk 的 entity index 拉取本帧需要模拟的 entity
- **怎么删除**：整个 SimRegion 在帧末丢弃，不单独删
- **容量上限**：编译期固定 4096
- **内存来源**：栈 / 单帧（SimRegion 本身的生命周期）
- **引用稳不稳**：单帧内有效，跨帧立刻失效（SimRegion 重建）
- **访问模式**：批量遍历（O(n²) 碰撞检测）

**代码**（`game/sim_region.odin`）：
```odin
SimRegion :: struct {
    high_entities:     [4096]HighEntity,   // 单帧投影，inline 存
    high_entity_count: u32,
    space:             Rectangle,
}

HighEntity :: struct {
    low_entity: ^LowEntity,                // 反指本体，end_sim 时回写
    rel_pos:    V3,                        // 相对 camera 的 float 坐标
}

begin_sim :: proc(state: ^GameState, memory: ^Memory) -> SimRegion {
    result := SimRegion{}
    // 遍历相关 chunk → 拉 entity index → 投影成 HighEntity
    for block := chunk.first_block; block != nil; block = block.next {
        for entity_id in block.entity_indexes[:block.entity_count] {
            low_entity := &state.entities[entity_id]
            result.high_entities[result.high_entity_count] = HighEntity{
                low_entity = low_entity,
                rel_pos    = relative_pos(low_entity.pos, state.camera_pos),
            }
            result.high_entity_count += 1
        }
    }
    return result
}

end_sim :: proc(state: ^GameState, sim_region: ^SimRegion) {
    // 把 HighEntity 改动写回 LowEntity，调整 chunk index
    for high_entity in sim_region.high_entities[:sim_region.high_entity_count] {
        high_entity.low_entity.pos = relative_world_pos(high_entity.rel_pos, state.camera_pos)
        reIndex(high_entity.low_entity)
    }
}
```

**反事实：如果不这样设计？**

| 备选方案 | 会出什么问题 |
|---|---|
| 不区分 high/low，所有 entity 都用统一结构 | 每帧所有 entity 都要算 rel_pos；缓存里掺杂大量本帧不需要模拟的 entity，密度变低 |
| HighEntity 常驻 GameState（不每帧重建） | 各种增删 use case（add_entity / 移动跨 chunk / camera 移动）都得维护 high 集合的同步，复杂度爆炸（见 `sim_region.md`）|
| HighEntity 完整拷贝整个 LowEntity（不存 `^LowEntity`） | end_sim 时要做双向 sync，容易漏字段；产生"权威数据是谁"的歧义 |
| 用 `[dynamic]HighEntity` 动态扩 | 与 arena 模型冲突；每帧都可能 realloc |

---

## 三、反复出现的权衡主线

把上表竖着读，会发现项目里的决策几乎都围绕这几条轴：

### 主线 1：存本体 vs 存引用（① + ⑦）

- 本体大、要频繁移动 → 存 index 或指针（chunk 里只放 u32 索引，SimRegion 里只放 `^LowEntity`）
- 本体小、想省一次指针跳转 → inline（前提是有"空"语义可以表达，否则要哨兵值）
- 见 `world_chunk.md` 决策 3、4

### 主线 2：静态上限 vs 动态扩张（⑤ + ⑥）

- Arena 不喜欢动态 realloc → 顶层都用**固定大小数组**（entities 10000、chunk_hash 4096、high_entities 4096）
- 必须动态的地方用**链表 + 固定大小节点**（chunk 链、block 链）
- 见 `world_chunk.md` 决策 1、2：拒绝 Odin map / 3D 数组

### 主线 3：创建快 vs 删除快（③ + ④）

- Arena 创建 O(1) 但不支持单点释放 → 配 free list（空闲 block 链表）
- 删除频繁的容器用 swap-and-pop（entities、entity index）
- 完全不删 → 整体丢弃重建（HighEntity）

### 主线 4：点查 vs 批量遍历决定结构（⑧ → ②）

- 点查（chunk 按 XYZ 找）→ hash + 链表，**节点粒度 = 1**
- 批量遍历（chunk 内 entity）→ unrolled list，**节点粒度 = cache line**
- 见 `world_chunk.md` 决策 7

### 主线 5：生命周期决定内存来源（⑥）

- 永久 → perm arena（LowEntity、WorldChunk、entity index）
- 单帧 → 栈或 temp arena（HighEntity）
- 可复用 → pool / free list（空闲 block）
- 见 `data_lifetime.md`、`game_memory.md`

### 主线 6：索引可丢、本体不能丢（① + ②的分离）

- chunk 索引坏了可以从 `entities[]` 重建
- `entities[]` 才是 source of truth
- 见 `store_vs_index.md` 6 条真理

---

## 四、设计新容器的 checklist

下次再设计一个容器（不管是 inventory、quest log、还是网络包队列），按这个顺序问自己一遍：

1. 数据**活多久**？→ 决定内存来源（arena 层）
2. **谁来访问**？点查还是遍历？→ 决定查找结构
3. 数据本体**多大**、**移动贵不贵**？→ 决定存本体还是存 index
4. 引用会不会**跨容器 / 跨帧**传播？→ 决定要不要 generation
5. 增删**有多频繁**？→ 决定 swap-and-pop / free list / 不删
6. 容量**能不能预估**？→ 决定固定数组还是链表
7. 遍历时**要不要 cache 友好**？→ 决定要不要 unrolled / SoA

这套清单基本能覆盖 `world_chunk.md`、`entity.md`、`sim_region.md`、`game_memory.md`、`data_structure.md` 里所有提到的决策。

---

## 参见

- [world_chunk](world_chunk.md) — L2/L3/L4 的完整设计
- [store_vs_index](store_vs_index.md) — 储存与索引分离的 6 条真理
- [data_lifetime](data_lifetime.md) — 生命周期分层
- [game_memory](game_memory.md) — Arena 模型
- [data_structure](data_structure.md) — 数据结构选择框架
- [sim_region](sim_region.md) — L5 的设计
- [entity](entity.md) — L1 的设计

---

**最后更新**: 2026-06-05

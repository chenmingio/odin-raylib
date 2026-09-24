# TODO

## 当前学习主线：Handmade Hero Day 070–080

执行顺序、当前代码差距、功能验收与可玩的互动见 [学习与移植计划](docs/guides/handmade_hero_day_070_080_plan.md)。目标是打通主岛、楼梯、高台的往返探索，并补齐高度碰撞、复合碰撞体和可通行范围。

- [ ] 70–72：坐标基准审计、重力/跳跃、三维模拟范围。
- [ ] 73–77：楼梯支撑、台阶高度、实体高度与脚点。
- [ ] 78：复合碰撞体与缺口场景。
- [ ] 79–80：Space、可通行边界及连接区域。
- [ ] 最终小关卡与旧移动/武器行为回归。

## 下一阶段：Handmade Hero Day 080–095

接续路线见 [80–95 学习与移植计划](docs/guides/handmade_hero_day_080_095_plan.md)。Day 80 为衔接验收点，81–95 重点推进渲染。

- [ ] 81–83：地面贴图合成、缓存与预乘 alpha。
- [ ] 84–87：滚动、跨帧缓存、chunk 对齐与无缝重建。
- [ ] 88–89：绘制命令缓冲及入口迁移。
- [ ] 90–93：坐标基、旋转缩放与纹理过滤。
- [ ] 94–95：线性光空间与正确预乘混合。
- [ ] 地面探索路线和渲染实验区验收。

## 内存系统

### [ ] 使用固定基地址分配游戏内存

模仿 Casey 的 Handmade Hero 内存模型，使用固定虚拟地址分配游戏内存，支持录制回放时指针保持有效。

**参考** (win32_handmade.cpp):

```c
#if HANDMADE_INTERNAL
    LPVOID BaseAddress = (LPVOID)Terabytes(2);
#else
    LPVOID BaseAddress = 0;
#endif
Win32State.GameMemoryBlock = VirtualAlloc(BaseAddress, TotalSize, ...);
```

**实现方案** (macOS):

```odin
import "core:sys/posix"

BASE_ADDRESS :: rawptr(uintptr(2 * mem.Terabyte))

addr := posix.mmap(
    BASE_ADDRESS,
    total_size,
    posix.PROT_READ | posix.PROT_WRITE,
    posix.MAP_PRIVATE | posix.MAP_ANON | posix.MAP_FIXED,
    -1,
    0,
)
```

**注意事项**:

- 只在 Debug 模式使用固定地址 (`when ODIN_DEBUG`)
- Release 模式让系统选择地址
- GameState 中的其他指针问题（`^image.Image`、`map` 等）需要另外处理

## Handmade Hero Day 64：SimRegion 实体引用映射

### [ ] 建立 `storage_index -> SimEntity` 映射并支持按需加载

**目标**：在一个 `SimRegion` 内，通过持久化的 `storage_index` 找到唯一的
`SimEntity`；实体关联（例如 `weapon`、`owner`）在模拟期间访问的是本帧的
sim entity，而非直接访问 stored entity。

**当前状态**：`LowEntity.owner` / `weapon` 保存 `u32` storage index；
`SimEntity` 仅保存 `^LowEntity`、`storage_index` 和相对坐标。关联实体只能
读取 stored entity，或线性扫描 `SimRegion.entities`。

**实现步骤**：

- 在 `SimRegion` 添加固定容量、开放寻址的 `SimEntityHashEntry` 数组：
  `{storage_index, entity: ^SimEntity}`。
- 实现 `get_sim_entity_by_storage_index` 与 `add_sim_entity`；后者必须先查询
  hash，保证每个 storage index 只创建一个 sim entity。
- `begin_sim` 通过 `add_sim_entity` 加载空间查询到的实体。
- 实现 `load_entity_reference`：关联 ID 非零且尚未加载时，从 `GameState` 的
  stored entity 按需加入当前 SimRegion；包括 non-spatial entity。
- 实现 `store_entity_reference`：`end_sim` 前把临时 sim-entity 引用恢复为
  持久化 storage index。

**当前架构的过渡方式**：先让 hash 只提供“唯一加载和快速查找”。等
`SimEntity` 改为完整的本帧副本后，再将 `owner` / `weapon` 在 sim 阶段解析为
`^SimEntity`，并在 `end_sim` 统一转回 storage index。

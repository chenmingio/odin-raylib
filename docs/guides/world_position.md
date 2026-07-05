World Position 坐标设计
=======================

## 问题背景

最朴素的世界坐标可以写成:

```text
x, y: float
```

问题是 float 的表达空间有限。世界坐标变大以后，整数部分占用更多精度，小数部分会变粗，角色移动、碰撞、渲染都会开始抖动或者丢细节。

所以更稳的方式是分层:

```text
WorldPosition = chunk_index + offset
```

整数部分负责大范围定位，float offset 只在 chunk 附近的小范围内表达细节。

## 两种常见约定

### 1. 左下角/最小角原点

```text
world = chunk * chunk_size + rel
rel in [0, chunk_size)
```

例子，`chunk_size = 1`:

```text
chunk 0 covers [0, 1)
chunk 1 covers [1, 2)
chunk -1 covers [-1, 0)
```

这种约定适合:

- tile 查询
- chunk hash / storage
- 加载和卸载
- 空间分桶

规范化时应该用 `floor`:

```odin
d := i32(math.floor(offset / chunk_size))
chunk += d
offset -= f32(d) * chunk_size
```

例子:

```text
chunk 10, offset  0.2 => chunk 10, offset 0.2
chunk 10, offset  1.2 => chunk 11, offset 0.2
chunk 10, offset -0.2 => chunk  9, offset 0.8
```

这个方案的重点是: offset 永远非负，负方向跨边界也能归到上一个 chunk 的正 offset。

### 2. 中心原点

```text
world = chunk_center + offset
offset in [-chunk_size / 2, chunk_size / 2)
```

例子，`chunk_size = 1`:

```text
chunk 0 covers [-0.5, 0.5)
chunk 1 covers [ 0.5, 1.5)
chunk -1 covers [-1.5, -0.5)
```

这种约定适合:

- 以 camera 为中心的模拟区域
- 大量 relative position 运算
- entity pivot / collision center 相关计算

规范化时更接近 `round` 语义:

```odin
d := i32(math.round(offset / chunk_size))
chunk += d
offset -= f32(d) * chunk_size
```

## Casey Day 080 的做法

Casey 在 Handmade Hero Day 080 使用中心原点。源码里 `world_position` 的注释是:

```cpp
// NOTE(casey): These are the offsets from the chunk center
v3 Offset_;
```

chunk 尺寸来自:

```cpp
#define TILES_PER_CHUNK 16
InitializeWorld(World, 1.4f, 3.0f);

World->ChunkDimInMeters = {
    TILES_PER_CHUNK * TileSideInMeters,
    TILES_PER_CHUNK * TileSideInMeters,
    TileDepthInMeters
};
```

所以 Day 080 里:

```text
TileSideInMeters = 1.4m
TILES_PER_CHUNK = 16
ChunkDimInMeters.x = 22.4m
ChunkDimInMeters.y = 22.4m
ChunkDimInMeters.z = 3.0m
```

他的 canonical 范围是中心对称的:

```cpp
TileRel >= -(0.5f * ChunkDim + Epsilon)
TileRel <=  (0.5f * ChunkDim + Epsilon)
```

规范化用的是 `roundf`:

```cpp
int32 Offset = RoundReal32ToInt32(*TileRel / ChunkDim);
*Tile += Offset;
*TileRel -= Offset * ChunkDim;
```

原因是中心 offset 要归到最近的 chunk center，而不是归到 chunk 的最小角。

## Odin 数值转换行为

本地 Odin 版本:

```text
odin version dev-2026-05:ea5175d86
```

实测行为:

| x | `i32(x)` | `math.floor(x)` | `math.ceil(x)` | `math.round(x)` | `math.trunc(x)` |
|---:|---:|---:|---:|---:|---:|
| `-2.7` | `-2` | `-3` | `-2` | `-3` | `-2` |
| `-2.5` | `-2` | `-3` | `-2` | `-3` | `-2` |
| `-1.5` | `-1` | `-2` | `-1` | `-2` | `-1` |
| `-0.7` | `0` | `-1` | `0` | `-1` | `0` |
| `-0.5` | `0` | `-1` | `0` | `-1` | `0` |
| `-0.3` | `0` | `-1` | `0` | `0` | `0` |
| `0.3` | `0` | `0` | `1` | `0` | `0` |
| `0.5` | `0` | `0` | `1` | `1` | `0` |
| `0.7` | `0` | `0` | `1` | `1` | `0` |
| `1.5` | `1` | `1` | `2` | `2` | `1` |
| `2.5` | `2` | `2` | `3` | `3` | `2` |

总结:

```text
i32(x)       向 0 截断
math.trunc   向 0 截断
math.floor   向负无穷
math.ceil    向正无穷
math.round   四舍五入，.5 远离 0
```

所以:

```odin
i32(-0.5) == 0
i32( 0.5) == 0

math.floor(-0.5) == -1
math.floor( 0.5) == 0

math.round(-0.5) == -1
math.round( 0.5) == 1
```

## 当前项目建议

如果 chunk 主要服务于 storage、hash、tile 查询和 reindex，建议使用左下角/最小角原点:

```text
chunkXYZ 表示 chunk 的最小角
offset in [0, chunkSideInMeters)
world = chunkXYZ * chunkSideInMeters + offset
```

这样代码心智模型最直接:

```text
chunk 10 + offset 0.3 = world 10.3
```

entity 自己的中心点、脚底点、sprite pivot、collision shape pivot 不要塞进 chunk offset 语义里，应该作为 entity/render/collision 自己的局部 offset 处理。

如果之后更强调 camera-centered simulation，可以改成 Casey 那种中心 offset，但要一起改 canonicalize、assert、relative_pos 的语义，不能混用。

## Epsilon 与边界

float 累加会出现这种值:

```text
0.99999994
```

数学上它可能应该是 `1.0`，但直接比较会留在当前 chunk。可以在 canonicalize 的最后做 snap:

```odin
eps :: f32(0.00001)

if offset >= chunk_size - eps {
	chunk += 1
	offset = 0
}
```

如果使用左下角 `[0, chunk_size)` 约定，推荐流程是:

```odin
d := i32(math.floor(offset / chunk_size))
chunk += d
offset -= f32(d) * chunk_size

if offset >= chunk_size - eps {
	chunk += 1
	offset = 0
}
```

这里不需要在 `floor` 前先加 eps。先做严格分块，再把贴近右边界的 offset snap 到下一个 chunk，语义更清楚，也更不容易把真实的 `0.99999` 过早进位。

## Camera 与屏幕位置

世界坐标原点和角色是否在屏幕中央没有直接关系。屏幕位置由 camera 决定:

```text
screen_pos = world_pos - camera_pos + screen_center
```

如果 `camera_pos` 跟随玩家，玩家就在屏幕中央。如果 `camera_pos` 是房间左下角、地图原点或者固定点，玩家就不会在中央。

也就是说，chunk offset 选左下角还是中心，主要影响 world position 的规范化和存储语义，不决定渲染相机策略。

## 代码流程

1. 根据 camera/world 查询相关 chunk。
2. 从 chunk 中收集 entity。
3. entity 持有绝对 `WorldPosition`。
4. 渲染时把 entity 的绝对位置转换为相对 camera 的位置。
5. 模拟时可以先转成局部相对坐标计算。
6. 模拟完成后再把结果 canonicalize 回 `WorldPosition`。
7. 如果 entity 跨 chunk，更新 chunk 里的 entity index。

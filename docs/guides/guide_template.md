# Guide 标题

| 字段 | 内容 |
|---|---|
| Status | Draft |
| Code scope | `TODO: 对应代码文件` |
| Last verified | TODO |

> 本文处于草稿状态。`TODO` 未完成前，不应把本文作为当前实现的唯一依据。

## 要解决的问题

<!-- TODO: 不要从 struct 字段开始。先描述没有这个模块时会遇到的具体问题。 -->

## 在整体架构中的位置

<!-- TODO: 谁调用它？它调用谁？在一帧或一次加载流程中的位置是什么？ -->

```text
TODO: 上游
  -> 本模块
  -> 下游
```

## 数据模型与所有权

<!-- TODO: 列出权威数据、索引/缓存/副本，以及拥有者。 -->

| 数据 | 所有者 | 生命周期 | 引用方式 | 是否权威 |
|---|---|---|---|---|
| TODO | TODO | TODO | value / pointer / index | TODO |

## 当前流程

<!-- TODO: 按真实执行顺序描述 Current，不要混入目标设计。 -->

1. TODO
2. TODO
3. TODO

## 关键不变量

- [ ] TODO: 无论怎样调用都必须成立的条件
- [ ] TODO

## 为什么这样设计

<!-- TODO: 写出收益和付出的代价。 -->

| 决策 | 收益 | 代价 |
|---|---|---|
| TODO | TODO | TODO |

## 替代方案

| 方案 | 优点 | 缺点 | 何时值得切换 |
|---|---|---|---|
| 当前方案 | TODO | TODO | — |
| Alternative A | TODO | TODO | TODO |

## 边界与失败模式

<!-- TODO: 容量、数值精度、调用顺序、并发、引用失效、资源失败。 -->

- **Known limitation**：TODO
- TODO

## Current、Target 与 Historical

### Current

<!-- TODO: 当前代码已经实现的能力。 -->

### Target

<!-- TODO: 尚未实现的下一步，说明为什么需要它。 -->

### Historical

<!-- TODO: Handmade Hero 或旧实现；不适用时删除本节。 -->

## 如何验证

| 风险 | 验证方式 | 当前是否存在 |
|---|---|---|
| TODO | test / assert / overlay / replay / profiling | TODO |

## 代码入口

- `TODO: file.odin` — TODO

## 相关文档

- [Guides 文档地图](README.md)
- TODO

## 完成检查

- [ ] 已区分 Current、Target、Alternative 和 Historical
- [ ] 数据所有权与生命周期明确
- [ ] 有一个端到端时序
- [ ] 写出了不变量
- [ ] 写出了当前方案的代价
- [ ] 写出了至少一个替代方案及切换条件
- [ ] 写出了容量、数值、顺序或并发边界
- [ ] 验证方式与仓库现状一致
- [ ] 代码名称和常量已按当前 commit 核对
- [ ] 相关链接有效

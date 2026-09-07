# Platform Input

| 字段 | 内容 |
|---|---|
| Status | Draft（框架） |
| Code scope | `platform/input.odin`、`game/controller.odin`、`main.odin` |
| Last verified | TODO |

> 本文解释 OS/Raylib 输入如何变成 Game 层可以记录和回放的抽象输入。

## 要解决的问题

<!-- TODO: 为什么 game code 不直接调用 Raylib 的 IsKeyDown？ -->

## Platform 到 Game 的边界

```text
Raylib keyboard/gamepad state
  -> platform mapping
  -> game.Input / ControllerInput
  -> gameplay update
  -> optional recording stream
```

<!-- TODO: 解释这个边界对热重载、测试、replay 和多平台的价值。 -->

## 当前数据模型

| 类型/字段 | 语义 | 生命周期 |
|---|---|---|
| `Input` | TODO | TODO |
| `ControllerInput` | TODO | TODO |
| `ButtonState.ended_down` | TODO | TODO |
| `half_transition_count` | TODO: 当前是否存在/使用 | TODO |

## 一帧中的输入流程

### 正常模式

1. TODO: poll device
2. TODO: map buttons
3. TODO: pass Input by value to game

### 录制模式

1. TODO: poll real input
2. TODO: append abstract Input to file
3. TODO: run game

### 回放模式

1. TODO: skip real device input
2. TODO: read abstract Input from file
3. TODO: run game

## Held、Pressed 与 Released

<!-- TODO: 当前只有 ended_down 能表达什么，不能表达什么？ -->

| 需求 | 只用 held state | 加 transition count/event |
|---|---|---|
| 连续移动 | TODO | TODO |
| 单次触发攻击 | TODO | TODO |
| 极短按键发生在两帧之间 | TODO | TODO |
| Replay | TODO | TODO |

## Key Mapping 与 Action Mapping

<!-- TODO: 当前是物理键到字段；何时值得引入 action map、remapping 或多个 device。 -->

## 多 Controller 和连接状态

<!-- TODO: controllers 固定容量、keyboard 占哪个 slot、isConnected 的语义。 -->

## 关键不变量

- [ ] Game 层不依赖 Raylib key enum。
- [ ] 正常模式和 replay 模式向 Game 提供相同布局的 Input。
- [ ] 每帧开始/结束时 button transition 数据按约定清理。
- [ ] TODO: controller slot 和 connection 不变量。

## 当前限制与替代方案

- **Known limitation**：TODO
- **Alternative**：event queue。
- **Alternative**：action mapping/rebinding layer。
- **Alternative**：记录原始平台事件而不是抽象 Input；解释为何通常不选。

## 如何验证

| 场景 | 验证方式 | 当前状态 |
|---|---|---|
| held movement | unit/manual | TODO |
| press once | unit/manual | TODO |
| replay matches recorded abstract input | integration test | TODO |
| controller disconnect/reconnect | manual test | TODO |

## 代码入口

- `platform/input.odin` — Raylib 到 ControllerInput
- `game/controller.odin` — 平台/game 共享的输入类型
- `main.odin` — normal/record/replay 分支
- `game/player.odin` — 当前输入消费者

## 相关文档

- [总体架构](architecture_overview.md)
- [Actor 状态](actor_state.md)
- [录制回放](plateform_record.md)
- [动态库](dynamic_lib.md)

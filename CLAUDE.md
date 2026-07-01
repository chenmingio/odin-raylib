# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

使用 Odin 语言和 Raylib 开发的 2D 游戏引擎，采用热重载架构，灵感来自 Handmade Hero。

## 构建命令

```bash
# Debug 构建（平台层 + 游戏库）
mkdir -p build && odin build . -debug -out:build/game -o:none && odin build game -out:build/game-lib.dylib -o:none -debug -build-mode:shared

# 仅构建平台层
odin build . -debug -out:build/game -o:none

# 仅构建游戏库（热重载时使用）
odin build game -out:build/game-lib.dylib -o:none -debug -build-mode:shared

# Release 构建
mkdir -p build && odin build . -out:build/game -o:speed && odin build game -out:build/game-lib.dylib -o:speed -build-mode:shared

# 运行
./build/game

# 创建/更新开发用 macOS app bundle
scripts/build_macos_app.sh --build

# 通过 app bundle 启动
open build/OdinRaylib.app

# 测试
odin test game
odin test platform
```

## 架构

```
main.odin          # 平台层入口，管理窗口、输入、音频、内存、热重载
├── platform/      # 平台层模块
│   ├── load_game.odin   # 动态库加载（热重载核心）
│   ├── record.odin      # 输入录制与回放
│   └── audio.odin       # 音频系统
└── game/          # 游戏逻辑（编译为动态库 game-lib.dylib）
    ├── game.odin        # 游戏主循环，导出 update_and_render
    ├── entity.odin      # 实体系统（类型、状态、方向）
    ├── world.odin       # 世界坐标系统（chunk + offset）
    ├── render.odin      # 软件渲染（draw_*, blend）
    └── animate.odin     # Aseprite 动画解析
```

### 平台层与游戏层分离

- **平台层** (`main.odin` + `platform/`)：静态链接，处理窗口、输入、音频、内存分配
- **游戏层** (`game/`)：编译为 `.dylib`，运行时动态加载，支持热重载

游戏层导出两个函数：
```odin
@(export) update_and_render: UpdateAndRenderProc
@(export) get_sound_samples: GetSoundSamplesProc
```

### 内存模型

使用 Arena 分配器，游戏状态存储在连续内存块中：
- `permanent_storage`: 256MB 永久内存（GameState 等）
- `temporary_storage`: 64MB 临时内存（图片加载等）

游戏通过 `Memory.perm_alloc` / `temp_alloc` 显式分配，不修改 `context.allocator`。

### 坐标系统

- **WorldPos**: `{chunk: V3i, offset: V3}` — 支持无限世界
- **ScreenPos**: 像素坐标，左上角为原点
- 单位转换: `SCALE = 100.0` (1米 = 100像素)

## 热重载开发流程

1. 运行 `./build/game`
2. 修改 `game/` 下的代码
3. 重新构建游戏库: `odin build game -out:build/game-lib.dylib -o:none -debug -build-mode:shared`
4. 平台层自动检测文件变化并重载（约每秒检查一次）

## 游戏控制

| 按键 | 功能 |
|------|------|
| WASD | 移动 |
| IJKL | 动作 |
| P | 暂停 |
| L | 录制/回放循环 |

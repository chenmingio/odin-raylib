# Odin Raylib 2D Game Engine

使用 Odin 语言和 Raylib 开发的 2D 游戏引擎，采用热重载架构，灵感来自 Handmade Hero。

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

## 构建

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

# 通过 app bundle 启动，获得稳定的 macOS application identity
open build/OdinRaylib.app
```

## 热重载开发流程

1. 运行 `./build/game`
2. 修改 `game/` 下的代码
3. 重新构建游戏库: `odin build game -out:build/game-lib.dylib -o:none -debug -build-mode:shared`
4. 平台层自动检测文件变化并重载（约每秒检查一次）

## 调试 (Zed 编辑器)

### 前提条件

安装 CodeLLDB 扩展：`Cmd+Shift+P` → `zed: extensions` → 搜索 `CodeLLDB` → 安装

### 调试配置

| 配置 | 用途 |
|------|------|
| Debug Odin Game | 启动调试，自动先执行 Build Debug |
| Attach to Running Game | 附加到已运行的游戏进程 |

### 使用方法

1. **启动调试**: `Cmd+Shift+P` → `debugger: start` → 选择 **Debug Odin Game**
2. **设置断点**: 在代码行号左侧点击
3. **附加调试**: 先运行游戏，再选择 **Attach to Running Game**

### 构建 Tasks

| Task | 用途 |
|------|------|
| Build Debug | 构建调试版本（平台层 + 游戏库） |
| Build Platform | 仅构建平台层 |
| Build Game Library | 仅构建游戏库（热重载时用） |
| Build macOS App | 构建调试版本并创建/更新开发用 `.app` |
| Run macOS App | 构建调试版本、更新 `.app` 并通过 app bundle 启动 |
| Build Release | 构建发布版本 |
| Run Game | 运行游戏 |
| Clean Build | 清理构建目录 |

运行 Task: `Cmd+Shift+P` → `task: spawn` → 选择任务

## 游戏控制

| 按键 | 功能 |
|------|------|
| WASD | 移动 |
| IJKL | 动作 |
| P | 暂停 |
| L | 录制/回放循环 |

## 测试

```bash
odin test game
odin test platform
```

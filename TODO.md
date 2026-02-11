# TODO

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

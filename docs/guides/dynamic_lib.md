Platform 动态库设计

我们希望开发的时候不要反复重启，可以热更新游戏逻辑。（比如原来一蹦三尺高，现在修改为一蹦五尺高，我希望在当前的场景下就能看到效果，方便我反复修改）。

那数据/游戏状态就不能重新生成，而是单独存在。游戏代码+游戏状态=游戏

流程

写完代码后，编译game code到指定位置(GAME_DLL_PATH :: "build/game-lib.dylib”)

C语言动态加载DLL，然后找到对应函数的symbol。找到的symbol要转换为对应的函数类型，才能安全使用。

编译game lib后自动加载
记录当前DLL的修改时间戳，当有新的DLL的时候，程序就可以自己发现并自动加载新DLL。

GameLib构成
画面更新：输入gameMemory/input/buffer后，返回下一帧的buffer
声音更新：buffer改为audio buffer


Dynamic Loading

每次循环都看下dll文件的修改时间。如果比上次晚，就重新load一下lib function。

lib function是通过external暴露出来，然后在platform的code里查询后引用。

Load的时候需要把指针转为函数指针：
Game->UpdateAndRender = (game_update_and_render *)
        dlsym(Game->GameCodeDLL, "GameUpdateAndRender");

game_update_and_render类型是通过一个宏和typedef来生成的。因为没找到复用，猜测直接定义函数也可以。

#define GAME_UPDATE_AND_RENDER(name) void name(game_memory *Memory, game_input *Input, game_offscreen_buffer *Buffer)

typedef GAME_UPDATE_AND_RENDER(game_update_and_render);


难点

之前用c语言一开始怎么都不成功，后来打开dll查看，发现cpp的export默认和c不一样，要写extern c这样的标注

Odin里则使用@(export)来表示

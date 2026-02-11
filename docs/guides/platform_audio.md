Platform Audio设计

Raylib平台

Raylib是callback式，相当于他每隔几个frame，会在另外的线程里调用你的callback函数。你的函数需要在他指定的buffer上copy要播放的内容。

所以理论上，你的game程序负责生产音频，在callback的时候，从上次上传的结尾地方开始续传。

但因为时间序列的消费数据是不需要保留历史数据的，所以可以用环形buffer来储存和消费内容。环形buffer的控制实现中，使用region1/2来管理越界的情况。


难点

理解音频的基本概念。采样率/深度等。然后是raylib的api，他的size到底是sample size还是frame size，是bit还是byte等

Sample vs Frame

  Sample = 单个采样值（一个数字）
  Frame  = 一个时间点的所有声道（立体声 = 2 samples）

  采样率 44100Hz = 每秒 44100 frames
  立体声 16-bit: 1 frame = 2 samples = 4 bytes


根据之前的经验，容易出错的是数据类型+ptr操作，特别是c语言里。比如u16类型的array，你用index每次移动也是u16，但data类型可能是u8，可能就会混淆。用odin的slice+index可以简化一些。

MAX_SAMPLES_PER_UPDATE：raylib内部有A/B两个buffer，一个消费的时候，一个就等待callback来填充。buffer的尺寸就是这个参数控制的，实际每次需要填充的size大概是这个的80%-100%之间。这个数值可以决定声音的延迟。如果这个buffer过小，或者生产的内容太慢了，audio就会读取不正确的内容，产生杂音。可以增加机制检查是否有underrun发生。


acc_time播放时间因为是float，时间变长以后精度会下降，需要mod一下。mod=period（波长）


overload和under-run：

1. 音频回调执行太慢 (overload)
   ↓
2. 系统跳过音频周期
   ↓  
3. 缓冲区没有及时填充
   ↓
4. 缓冲区变空 (underrun)
   ↓
5. 播放静音或噪音


技巧

可视化： 音频很难debug，你不知道是哪里出了问题。但是变成可视化的波形以后就非常清晰（相反web开发可能就难以可视化）。

Guard：设置多个assert，及时捕捉代码异常

underrun/overrun检测

TODO

把index变成原子操作类型，或者封装到模块里。

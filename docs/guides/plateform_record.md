Platform 录播设计

按下record键以后，当时的game memory就被保存为一个文件。与之对应的，结束以后，文件内容就被加载为game memory了。

同时，按下record以后的输入（input stream），也需要保存和载入（回放）。input stream也在game memory结构里，所以不用单独存文件。


Record时

copy所有memory到文件里，把write指向input区，然后每次loop都write一个input的内容

[游戏内存状态 - 64MB][Input1][Input2][Input3]...[InputN]
 ↑                                 ↑
 位置 0                         位置 64MB (fwrite后指针在这里)


Replay时

copy文件到memory里，把read指向input区，每次loop都载入一个input

当read到底的时候，重新这个步骤


难点

之前把permanent/temporary的内存块分两次make，地址不是连续的，造成没办法一次copy。所以要一次分配total size后再分割。

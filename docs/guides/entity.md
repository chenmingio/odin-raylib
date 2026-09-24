# Entity

储存

以固定长度的array储存entity的value。因为value不能为nil，所以需要用一个count来追踪最后一个entity的位置。

删除entity

方案1: count减一，把最后一个entity复制到删除的那个slot里。
方案2: count不变，把删除的空位加入free list里。下次分配时，优先使用free list里的空位。

不过目前Casey没有处理删除逻辑

## 问题：
### 0 是否有保留语义，当前代码如何处理；

### owner、weapon 等跨 entity 引用为什么存 index；
地址/pointer引用容易失效，特别是memory reload以后

### non_spatial、moveable、collides、updatable 的区别；
是否移动（不移动就不主动参加碰撞算法）

  
### 删除当前只是把 index 加入 free list，尚未形成完整销毁协议；

### index 被复用时旧引用可能指向新 entity，何时需要 generational handle；

### entity 字段混合 render、physics、gameplay 数据的便利与代价。

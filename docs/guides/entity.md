Entity

储存

以固定长度的array储存entity的value。因为value不能为nil，所以需要用一个count来追踪最后一个entity的位置。

删除entity

方案1: count减一，把最后一个entity复制到删除的那个slot里。
方案2: count不变，把删除的空位加入free list里。下次分配时，优先使用free list里的空位。

不过目前Casey没有处理删除逻辑

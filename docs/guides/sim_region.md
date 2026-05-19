为什么需要sim region
- 有限的资源，不可能模拟所有的运动
- 

### 为什么需要区分low_entity和high_entity?
- 信息差异
  - 模拟中的entity需要使用完全的float做模拟，一般的entity有chunk部份，需要转化为相对于camera pos的rel地址。
- 集中力量办大事
  - 缓存优势（low entity是大量且分散分布的，high entity是连续的）
  - focus（把有限的算力放到关注的区域里）

### high entity需要复制low entity的内容吗？
不要，不然就有同步的问题了。


## 流程

orm/缓存模型里，也有hot/cold区的概念。把数据页从磁盘中提高到RAM里，相当于从low entity变成了high entity。游戏没有entity级别的持久化概念，但是high entity更新好移动状态后，同样需要更新low entity的位置。

high entity的添加时机
- 初始化时？把region里的chunk一次加入
- 创建entity（add entity）时？
- 移动entity到zone时？
- 移动camera时？

high entity的移除时机
- 单个high entity更新pos之后？
- 是否需要loop high-entity然后一起移除？
- remove entity

如果把high entity作为一个固定集合每次统计增删，有点麻烦（需要在各个usecase里加入CRUD逻辑）。简单方法就是每次loop都新建sim和他的high entity（目前是根据位置找到chunk）。

开始Sim
- 把模拟区域里chunk的所有entity找到
- 添加到high entity里

模拟
- 游戏逻辑
- 碰撞逻辑
- 根据碰撞结果更新位置

结束Sim
- 把sim region里的high entity的新状态保存到low entity里
  - low entity的chunk可能改变，原来的chunk里的entity id需要移动到新的chunk里
  - high entity的value修改也需要覆盖回state的low entity里。

World Position坐标设计

世界坐标WorldPos

最朴素的坐标

x,y : float

问题：因为float的表达空间有限
- 最多64位
- 精度会变化。如果整数部分很大，小数精度就很小（比如只有0.5），就会漂移


最朴素的分层坐标：整数+小数

X,Y: int
RelX, RelY: float

相当于chunk size = 1 m


分层坐标Pro：tile+tileRel分层

ChunkX, ChunkY: int
RelX, RelY: float
Entity移动时，需要更新chunk的XY和entity的储存位置



原点在哪里

地图的左上角 vs 地图的中心

使用unsigned代表坐标，原点位置为0，那就不能简单的向左移动了。（需要用unsigned integer做underflow到地图的最右边去）。这样的逻辑太复杂了，收益不大。如果原点位置在maxInt/2，又很奇怪。

用signed integer，原点位置为0，这样最简单。





Camera坐标 

渲染屏幕基于相对坐标。屏幕坐标=WorldPos 减去 camera坐标 =相对坐标。

CameraPos：relXYZ，不需要chunk的概念了

碰撞检测与坐标

检测多大范围里的entity之间的碰撞？
比屏幕大一点（或者比玩家关心的范围大一点的区域）

未来检测范围hotZone之外的entity怎么做低分辨率的移动？

碰撞是否涉及chunk？还是先转为relXYZ来计算？


计算以后得出的新Pos要怎么更新到WorldPos里？




接口设计
TODO


代码流程
1. 根据cameraPos找到相关的chunk
2. 找到chunk里的所有entity
3. entity包含绝对pos(worldPos)
4. 把chunk里的entity render出来
    1. 绝对pos转为相对camera的pos


运动和碰撞

计算运动和碰撞使用绝对坐标还是相对坐标？
- 绝对坐标，这样可以计算屏幕外的碰撞

先计算碰撞

然后计算运动

- move(worldPos, delta)
    - 更新entity的worldPos
    - 更新entity的chunk index（移动chunk里的entity index）

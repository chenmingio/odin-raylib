package playground

import "core:fmt"

main :: proc() {

	// 固定长度array
	// 类型是[5]int，和[3]int是不同的类型
	xs := [5]int{1, 2, 3, 4, 5}
	// x := [?]int{1, 2, 3, 4, 5} 也可以用？来自己推导长度
	fmt.println(len(xs))

	// 特殊的构造方式
	favorite_animals := [?]string {
		// Assign by index
		0 = "Raven",
		1 = "Zebra",
		2 = "Spider",
		// Assign by range of indices
		3 ..= 5  = "Frog",
		6 ..< 8  = "Cat",
	}
	fmt.println(favorite_animals)

	// slice，保存指针/长度(貌似没容量，只有dynamic array有cap)
	// slice就是一个指针指向数据，但本身不保存数据
	s1 := []int{1, 2, 3}

	Player :: string
	// Dynamic Array - 用于需要动态增长的数据
	players := [dynamic]Player{}
	new_player := Player("hellope")
	append(&players, new_player) // 添加新玩家

	// Slice - 用于访问部分数据
	active_count := 3
	active_players := players[0:active_count] // 只看前N个活跃玩家
}

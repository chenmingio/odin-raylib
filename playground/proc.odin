package playground

import "core:fmt"

main :: proc() {
	foo :: proc(x: int) {
		x := x // 可以遮盖参数
		for x > 0 {
			fmt.println(x)
			x -= 1
		}
	}

	foo(5)

	// 参数可以不定数量
	sum :: proc(nums: ..int) -> (result: int) {
		for n in nums {
			result += n
		}
		return
	}
	fmt.println(sum()) // 0
	fmt.println(sum(1, 2)) // 3
	fmt.println(sum(1, 2, 3, 4, 5)) // 15

	// 解包array
	odds := []int{1, 3, 5}
	fmt.println(sum(..odds))

	// 返回多个值
	swap :: proc(x, y: int) -> (int, int) {
		return y, x
		// return 裸return可以返回具名变量
	}
	a, b := swap(1, 2)
	fmt.println(a, b) // 2 1

	// 返回具名变量并且有默认值
	conditionally_blue :: proc(red: bool) -> (color := "blue") {
		if red {
			return "red"
		}
		return
	}

	// 混合调用参数（位置+具名参数）
	bar :: proc(value: int, name: string, x: bool, y: f32, z := 0) {}
	bar(134, "hellope", x = true, y = 4.5)


}

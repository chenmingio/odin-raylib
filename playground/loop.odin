#+feature dynamic-literals
package playground
import "core:fmt"

main :: proc() {
	for i := 0; i < 3; i += 1 {
		fmt.eprintln(">>> loop", i)
	}

	for i in 0 ..= 3 {
		fmt.eprintln(">>> loop", i)
	}

	some_string := "Hello, 世界"
	some_array := [3]int{1, 4, 9}
	some_slice := []int{1, 4, 9}
	some_dynamic_array := [dynamic]int{1, 4, 9} // must be enabled with `#+feature dynamic-literals`
	defer delete(some_dynamic_array)
	for value in some_dynamic_array {
		fmt.println(value)
	}

	some_map := map[string]int {
		"A" = 1,
		"C" = 9,
		"B" = 4,
	} // must be enabled with `#+feature dynamic-literals`
	defer delete(some_map)
	for key in some_map {
		fmt.println(key)
	}

	// 对于一些在heap上分配的数据(map,dynamic array, 一些string，需要函数结束的时候defer delete

	// for value in xxx这时只读复制，但是&value是可写的
	for &value in some_array {
		value = 42
	}
	fmt.println(some_array)

	for &value in some_slice {
		value = 42
	}
	fmt.println(some_slice)

	for &value in some_dynamic_array {
		value = 42
	}
	fmt.println(some_dynamic_array)
	// does not impact the second index value
	for &value, index in some_dynamic_array {
		value = 42
	}
	fmt.println(some_dynamic_array)

	for key, &value in some_map {
		value += 1
	}

	fmt.println(some_map["A"]) // 2
	fmt.println(some_map["C"]) // 10
	fmt.println(some_map["B"]) // 5

}

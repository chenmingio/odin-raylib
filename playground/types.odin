package playground

import "core:fmt"

main :: proc() {
	// pointer
	num := 1
	p: ^int = &num
	fmt.println(&p)

	// 类型转换+推导
	i := 123
	f := f32(i)
	u := u32(f)
	u2 := transmute(u32)f
	fmt.println(u2)


	// 这些是constant，可以隐式转换为任何类型
	I :: 42 // untyped integer, will implicitly convert to any numeric type (int, u32, f64, quaternion128 etc)
	F :: 1.37 // untyped float,  will implicitly convert to any numeric type that can support fractional parts (f64, quaternion128 etc)
	S :: "Hellope" // untyped string,  will implicitly convert to string and cstring
	B :: true // untyped boolean, will implicitly convert to bool, b8, b16, etc.

	// 可以给类型起别名
	My_Int :: distinct int
	// 包括复合类型
	Vector3 :: [3]f32

	// sum type
	Value :: union {
		bool,
		i32,
		f32,
		string,
	}
	v: Value
	v = "Hellope"

	// type assert that `v` is a `string` and panic otherwise
	s1 := v.(string)

	// type assert but with an explicit boolean check. This will not panic
	s2, ok := v.(string)
}

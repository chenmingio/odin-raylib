package playground

import "core:fmt"

main :: proc() {
	// 自动初始化为0
	x, y: int
	x = 1
	x = 2
	// x := 3 不能重复定义

	// := 是两个操作，等于: (int) = 3，int因为可以推导为默认值所以省略了
	z: int = 3
	z1, z2 := "hello", 5

	fmt.eprintln(">>> playground", x, y, z, z1, z2)

	// raw string 就不转义
	normal_string := "Hello\nWorld" // \n 是换行符
	raw_string := `Hello\nWorld` // \n 是字面字符

	face := "\U0001F600"
	fmt.eprintln(">>> string", normal_string, raw_string, face)

	big_num := 1_000_000
	big_float := 1.0e9
	imaginary := 1.0i

	binary := 0b1010
	ocat := 0o12
	hex := 0x1A

	fmt.eprintln(">>> number", big_num, big_float, imaginary, binary, ocat, hex)

	// 因为变量需要立刻知道类型，所以使用字面量的默认类型
	// 整数字面量的默认类型是 int
	x1 := 1 // x 的类型是 int

	// 浮点字面量的默认类型是 f64
	y1 := 3.14 // y 的类型是 f64

	// 字符串字面量的默认类型是 string
	z3 := "hello" // z 的类型是 string

	// 当知道变量的类型时，字面量可以自动转换为目标类型
	// 同一个字面量 42，不同上下文不同类型
	a1: int = 42 // 42 变成 int
	b1: f32 = 42 // 42 变成 f32
	c1: i8 = 42 // 42 变成 i8

	// 字面量 3.0 的灵活性
	d1: int = 3.0 // 3.0 变成 int 3（无精度损失）
	e1: f64 = 3.0 // 3.0 变成 f64 3.0

	// 定量: 按无类型处理
	what :: "what" // constant `x` has the untyped string value "what"
	c2: int : 1 // 这个常量就有类型了
	c3 :: c2 + 1

	// map
	m := make(map[string]int)
	defer delete(m)
	m["Bob"] = 42
	fmt.println(m["Bob"])

	// struct
	Vector2 :: struct {
		x: f32,
		y: f32,
	}
	v := Vector2{1, 2}
	v.x = 4
	fmt.println(v.x)

	// struct的另一种初始化方式，只给部份key assign value
	v2 := Vector2 {
		x = 1,
	}
	fmt.println(v2)

}

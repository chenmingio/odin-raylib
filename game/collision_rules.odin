package game

import "core:math"

PairwiseCollisionRule :: struct {
	entity_a:    u32,
	entity_b:    u32,
	can_collide: bool,
	next:        ^PairwiseCollisionRule,
}

collision_rule_hash :: proc(ety_a: u32, ety_b: u32) -> (u32, u32, u32) {
	min_ety_index := math.min(ety_a, ety_b)
	max_ety_index := math.max(ety_a, ety_b)
	hash := min_ety_index % 256
	return min_ety_index, max_ety_index, hash
}

get_collision_rule :: proc(ety_a: u32, ety_b: u32, state: ^GameState) -> ^PairwiseCollisionRule {
	min_ety_index, max_ety_index, hash := collision_rule_hash(ety_a, ety_b)
	bucket := state.collision_rule_hash[hash]
	for rule := bucket; rule != nil; rule = rule.next {
		if rule.entity_a == min_ety_index && rule.entity_b == max_ety_index {
			return rule
		}
	}
	return nil
}

// find a place in memory to store rule (free list or new memory location)
new_collison_rule :: proc(state: ^GameState, memory: ^Memory) -> ^PairwiseCollisionRule {
	result: ^PairwiseCollisionRule
	first_free := state.first_free_collision_rule
	if first_free != nil {
		state.first_free_collision_rule = first_free.next
		result = first_free
	} else {
		result = new(PairwiseCollisionRule, memory.perm_alloc)
	}
	return result
}

// 查重/幂等
add_collision_rule :: proc(
	ety_a: u32,
	ety_b: u32,
	can_collide: bool,
	state: ^GameState,
	memory: ^Memory,
) {
	min_ety_index, max_ety_index, hash := collision_rule_hash(ety_a, ety_b)
	// try to get rule if already exist
	test := get_collision_rule(ety_a, ety_b, state)
	if (test != nil) {
		test.can_collide = can_collide
		return
	}

	// get store location
	new_rule := new_collison_rule(state, memory)

	// add rule to bucket-rule-chain's head
	bucket: ^PairwiseCollisionRule = state.collision_rule_hash[hash]
	state.collision_rule_hash[hash] = new_rule

	new_rule^ = PairwiseCollisionRule{min_ety_index, max_ety_index, can_collide, bucket}
}

clear_collision_rules_for :: proc(ety: u32, state: ^GameState) {
	for hash in 0 ..< len(state.collision_rule_hash) {
		// 不常见的技巧
		// link指向hash的bucket的地址本身，而不是bucket地址内的rule地址。
		// link语义上我们把他指向“储存rule的容器”本身，而不是“rule”。
		// 这样可以解决prev的问题（link相当于prev的next，让你可以修改prev的next）
		// link^就是“容器内储存的rule”
		link := &state.collision_rule_hash[hash]
		for link^ != nil {
			rule := link^
			if rule.entity_a == ety || rule.entity_b == ety {
				// 把容器内存上“link里当前rule的下一个rule的地址”
				link^ = rule^.next
				// 清空内容
				rule^ = PairwiseCollisionRule{}

				// 回收rule到free list
				first_free := state.first_free_collision_rule
				state.first_free_collision_rule = rule
				rule.next = first_free
			} else {
				link = &link^.next
			}
		}
	}
}

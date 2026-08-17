package game

EntityType :: enum {
	Null,
	Player,
	Enemy,
	Tree,
	Wall,
	Weapon,
	Stair,
}

EntityStatus :: enum {
	Idle,
	Walk,
	Run,
	Attack_1,
	Attack_2,
	Guard,
	Throw,
}

Direction :: enum {
	Forward,
	Backward,
}

status_names := [EntityStatus]string {
	.Idle     = "Idle",
	.Walk     = "Walk",
	.Run      = "Run",
	.Attack_1 = "Attack 1",
	.Attack_2 = "Attack 2",
	.Guard    = "Guard",
	.Throw    = "Throw",
}

entity_status_to_name :: proc(s: EntityStatus) -> string {
	return status_names[s]
}

name_to_entity_status :: proc(name: string) -> (EntityStatus, bool) {
	for s in EntityStatus {
		if status_names[s] == name {
			return s, true
		}
	}
	return EntityStatus.Idle, false
}

LowEntity :: struct {
	pos:                   WorldPosition,
	type:                  EntityType,
	size:                  V3,
	// render相关
	status:                EntityStatus,
	anim_frame_idx:        i32,
	anim_elapsed_time:     i32, // ms,当前frame花了多少时间，在切换frame以后清零
	direction:             Direction,
	// 碰撞相关
	moveable:              bool, //是否移动，比如墙就不能移动
	non_spatial:           bool, //是否在simRegion里参与模拟
	dp:                    V3, // derivative of p
	ddp:                   V3, // derivative of dp
	hit_point_total:       i32,
	hit_point_left:        i32,
	// 游戏逻辑相关
	owner:                 u32,
	weapon:                u32,
	target_pos:            WorldPosition,
	flight_time_remaining: i32, // ms
	attack_cooldown:       f32, // 目前用anim_elapsed_time代替
	collides:              bool, // false：纯装饰物：草、背景石头、特效、粒子。
	stair_direction:       StairDirection,
	stair_level:           u8,
}

SimEntity :: struct {
	low_entity:    ^LowEntity,
	storage_index: u32,
	p:             V3,
	to_remove:     bool,
	updatable:     bool,
}


remove_entity_from_entity_list :: proc(state: ^GameState, index: u32) {
	state.free_entity_index_list[state.free_entity_index_count] = index
	state.free_entity_index_count += 1
}


add_low_entity :: proc(state: ^GameState, entity: LowEntity, memory: ^Memory) -> u32 {
	// get entity index
	entity_index: u32
	if state.free_entity_index_count > 0 {
		entity_index = state.free_entity_index_list[state.free_entity_index_count - 1]
		state.free_entity_index_count -= 1
	} else {
		entity_index = state.low_entity_count
		state.low_entity_count += 1
	}

	stored_entity := entity
	if !entity.non_spatial {
		stored_entity.pos = canonicalize(state.world, stored_entity.pos)
	}
	state.low_entities[entity_index] = stored_entity

	// 添加entity chunk index
	if !stored_entity.non_spatial {
		add_entity_index_to_hash_chunk(state, memory, entity_index, stored_entity.pos.chunkXYZ)
	}
	return entity_index
}

get_low_entity :: proc(state: ^GameState, index: u32) -> ^LowEntity {
	return &state.low_entities[index]
}

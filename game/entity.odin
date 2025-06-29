package game

EntityType :: enum {
	Null,
	Player,
	Enemy,
	Tree,
	Wall,
}

Entity :: struct {
	pos:  WorldPos,
	type: EntityType,
	size: V2,
}

package game

EntityType :: enum {
	Player,
	Enemy,
	Tree,
	Wall,
}

Entity :: struct {
	pos:  WorldPos,
	type: EntityType,
}

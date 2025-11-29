extends Node3D
class_name Tile

enum TileKind {
	NORMAL,
	START,
	GOAL,
	LADDER_START,
	LADDER_END,
	TUNNEL_START,
	TUNNEL_END,
}

@export var kind: TileKind = TileKind.NORMAL
@export var index: int = 0

# Pro žebřík a tunely:
# LADDER_START používá jen jump_target_index_1
# TUNNEL_START používá jump_target_index_1 a jump_target_index_2
@export var jump_target_index_1: int = -1  # ladder / dobrý tunel
@export var jump_target_index_2: int = -1  # špatný tunel

@onready var player_spot: Marker3D = %PlayerSpot

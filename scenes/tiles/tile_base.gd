extends Node3D

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

# Pro LADDER_START a TUNNEL_START:
# kam má hráč skočit, když na tohle políčko stoupne
@export var jump_target_index: int = -1

@onready var player_spot: Marker3D = %PlayerSpot

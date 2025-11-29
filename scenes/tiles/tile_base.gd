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

@export var accent_color: Color = Color.WHITE:
	set(value):
		accent_color = value
		_apply_accent_color()
		
# child scéna cesta na mesh, který má být barevný
@export var color_mesh_path: NodePath

@onready var player_spot: Marker3D = %PlayerSpot

func _ready() -> void:
	_apply_accent_color()


func _apply_accent_color() -> void:
	if color_mesh_path == NodePath():
		return

	var mesh = get_node_or_null(color_mesh_path) as MeshInstance3D
	if mesh == null:
		return

	# vezmeme první surface materiál a zduplikujeme ho
	var base_mat := mesh.get_active_material(0)
	var mat: StandardMaterial3D

	if base_mat:
		mat = base_mat.duplicate()
	else:
		mat = StandardMaterial3D.new()

	mat.albedo_color = accent_color
	mesh.set_surface_override_material(0, mat)

extends Node3D

enum PlayerType { HUMAN, ENEMY }

@export var player_type: PlayerType = PlayerType.HUMAN
@export var player_index: int = 0      # 0..3
@export var color: Color = Color(1, 1, 1)
@export var colorBelly: Color = Color(1, 1, 1)
@onready var active_indicator: Node3D = $ActiveIndicator

var current_tile_index: int = 0
var is_on_turn: bool = false
var board                    # odkaz na Game/Board
var is_moving: bool = false
var is_finished: bool = false 

var positions = [
	Vector3(-0.2, -0.3, -0.2), # hráč 0
	Vector3(0.2, -0.3, -0.2), # hráč 1
	Vector3(-0.1, -0.8,  -0.2), # hráč 2
	Vector3(0.3, -0.8,  -0.2), # hráč 3
]
signal movement_started(player)
signal movement_finished(player)

@onready var follow_camera: Camera3D = $FollowCamera
@onready var model = $Model
@onready var anim_player: AnimationPlayer = $playerglb/AnimationPlayer
@onready var cylinder_002: MeshInstance3D = $playerglb/rig/Skeleton3D/Cylinder_002
@onready var icosphere: MeshInstance3D = $playerglb/rig/Skeleton3D/Icosphere
@onready var cylinder_003: MeshInstance3D = $playerglb/rig/Skeleton3D/Cylinder_003
@onready var player: MeshInstance3D = $playerglb/rig/Skeleton3D/Player

func _ready():
	# základ – obarví model (pokud má MeshInstance3D s material override nebo modulate)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	var matBelly = StandardMaterial3D.new()
	matBelly.albedo_color = colorBelly
	cylinder_002.material_override = mat
	cylinder_003.material_override = mat
	icosphere.material_override = mat
	player.material_override = matBelly

func move_steps(steps: int) -> void:
	if is_moving or board == null:
		return

	is_moving = true
	movement_started.emit(self)
	anim_player.play("Walk", -1,1.0 ,true)
	anim_player.speed_scale= 4
	var target = min(current_tile_index + steps, board.tiles.size() - 1)

	for i in range(current_tile_index + 1, target + 1):
		await move_to_index(i)

	current_tile_index = target
	is_moving = false
	anim_player.speed_scale= 1
	anim_player.play("Idle")

	movement_finished.emit(self)
	board.on_player_finished_move(self)


func move_to_index(tile_index: int) -> void:
	movement_started.emit(self)
	var tile = board.tiles[tile_index]
	var offset: Vector3 = positions[player_index]
	var target_pos: Vector3 = tile.player_spot.global_position + offset
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_pos, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	current_tile_index = tile_index
	movement_finished.emit(self)
	

func set_on_turn(active: bool) -> void:
	is_on_turn = active
	if active_indicator:
		active_indicator.visible = active

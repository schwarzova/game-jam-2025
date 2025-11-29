extends Node3D

enum PlayerType { HUMAN, ENEMY }

@export var player_type: PlayerType = PlayerType.HUMAN
@export var player_index: int = 0      # 0..3
@export var color: Color = Color(1, 1, 1)
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

@onready var model = $Model
@onready var anim_player: AnimationPlayer = $playerglb/AnimationPlayer


func _ready():
	# základ – obarví model (pokud má MeshInstance3D s material override nebo modulate)
	if model is MeshInstance3D:
		model.modulate = color

func move_steps(steps: int) -> void:
	if is_moving or board == null:
		return

	is_moving = true
	anim_player.play("Walk", -1,1.0 ,true)
	anim_player.speed_scale= 7
	var target = min(current_tile_index + steps, board.tiles.size() - 1)

	for i in range(current_tile_index + 1, target + 1):
		await move_to_index(i)

	current_tile_index = target
	is_moving = false
	anim_player.speed_scale= 1
	anim_player.play("Idle")

	board.on_player_finished_move(self)


func move_to_index(tile_index: int) -> void:
	var tile = board.tiles[tile_index]
	var offset: Vector3 = positions[player_index]
	var target_pos: Vector3 = tile.player_spot.global_position + offset
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_pos, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	current_tile_index = tile_index
	

func set_on_turn(active: bool) -> void:
	is_on_turn = active
	if active_indicator:
		active_indicator.visible = active

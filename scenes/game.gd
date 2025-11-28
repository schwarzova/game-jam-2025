extends Node3D

const BOARD_WIDTH := 10
const BOARD_HEIGHT := 10

@export var tile_normal_scene: PackedScene
@export var tile_start_scene: PackedScene
@export var tile_goal_scene: PackedScene
@export var tile_ladder_start_scene: PackedScene
@export var tile_ladder_end_scene: PackedScene
@export var tile_tunnel_start_scene: PackedScene
@export var tile_tunnel_end_scene: PackedScene

var tiles: Array[Node3D] = []

func _ready() -> void:
	_build_board()
	_setup_special_tiles()
	
func _build_board():
	tiles.resize(BOARD_WIDTH * BOARD_HEIGHT)
	var index := 0

	var tile_size := 1.01      # rozestup mezi krychlema v X
	var step_height := 1.0    # výška jednoho schodu
	var step_depth := 1.01     # posun v ose Z na další schod

	for row in range(BOARD_HEIGHT):
		for col in range(BOARD_WIDTH):
			var scene: PackedScene = tile_normal_scene

			if index == 0:
				scene = tile_start_scene
			elif index == BOARD_WIDTH * BOARD_HEIGHT - 1:
				scene = tile_goal_scene

			var tile = scene.instantiate() as Node3D
			tile.index = index

			# Pozice: x = sloupec, y = schod, z = schod
			var x = float(col) * tile_size
			var y = float(row) * step_height
			var z = float(row) * step_depth

			tile.global_position = Vector3(x, y, z)

			$TilesRoot.add_child(tile)
			tiles[index] = tile

			index += 1
			
func _setup_special_tiles():
	# Příklad: žebřík z 5 na 22
	_make_ladder(5, 22)

	# Příklad: tunel z 30 na 12
	_make_tunnel(30, 12)
	
func _replace_tile(index: int, scene: PackedScene) -> Node3D:
	var old_tile = tiles[index]
	var new_tile = scene.instantiate() as Node3D
	new_tile.index = index
	new_tile.global_position = old_tile.global_position

	old_tile.queue_free()
	$TilesRoot.add_child(new_tile)
	tiles[index] = new_tile

	return new_tile
	
func _make_ladder(start_index: int, end_index: int):
	var start_tile = _replace_tile(start_index, tile_ladder_start_scene)
	start_tile.jump_target_index = end_index
	start_tile.kind = start_tile.TileKind.LADDER_START

	var end_tile = _replace_tile(end_index, tile_ladder_end_scene)
	end_tile.kind = end_tile.TileKind.LADDER_END
	
func _make_tunnel(start_index: int, end_index: int):
	var start_tile = _replace_tile(start_index, tile_tunnel_start_scene)
	start_tile.jump_target_index = end_index
	start_tile.kind = start_tile.TileKind.TUNNEL_START

	var end_tile = _replace_tile(end_index, tile_tunnel_end_scene)
	end_tile.kind = end_tile.TileKind.TUNNEL_END

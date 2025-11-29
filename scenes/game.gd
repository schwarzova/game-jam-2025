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
@export var player_scene: PackedScene

var tiles: Array[Node3D] = []
var players: Array = []
var current_player_index: int = 0

@onready var players_root = $PlayersRoot
@onready var btn_dice = $CanvasLayer/HUD/BottomRightActions/BtnDice
@onready var btn_courage = $CanvasLayer/HUD/BottomRightActions/BtnCourage
@onready var btn_drop = $CanvasLayer/HUD/BottomRightActions/BtnDrop
@onready var tunnel_panel = $CanvasLayer/HUD/TunnelChoice
@onready var btn_tunnel_left = $CanvasLayer/HUD/TunnelChoice/LeftTunnel
@onready var btn_tunnel_right = $CanvasLayer/HUD/TunnelChoice/RightTunnel

var _tunnel_choice: int = -1  # -1 = no, 0 = left, 1 = right
var tunnel_left_is_good: Dictionary = {}

func _ready() -> void:
	_build_board()
	_setup_special_tiles()
	_setup_ui_signals()
	_spawn_players(2, 2) # třeba default – 2 hráči, 2 nepřátelé
	
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
	_make_ladder(5, 22)
	_make_ladder(16, 38)
	_make_ladder(40, 88)
	_make_ladder(59, 95)

	_make_tunnel(30, 12)
	_make_tunnel(65, 8)
	_make_tunnel(10, 4)
	
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
	start_tile.jump_target_index_1 = end_index
	start_tile.kind = start_tile.TileKind.LADDER_START

	var end_tile = _replace_tile(end_index, tile_ladder_end_scene)
	end_tile.kind = end_tile.TileKind.LADDER_END
	
func _make_tunnel(start_index: int, good_index: int):
	var start_tile = _replace_tile(start_index, tile_tunnel_start_scene)
	start_tile.jump_target_index_1 = good_index
	start_tile.jump_target_index_2 = 0 # Start index
	start_tile.kind = start_tile.TileKind.TUNNEL_START

	var end_tile = _replace_tile(good_index, tile_tunnel_end_scene)
	end_tile.kind = end_tile.TileKind.TUNNEL_END
	
	tunnel_left_is_good[start_index] = randf() < 0.5
	
func _setup_ui_signals():
	btn_dice.pressed.connect(_on_dice_pressed)
	btn_courage.pressed.connect(_on_courage_pressed)
	btn_drop.pressed.connect(_on_drop_pressed)
	btn_tunnel_left.pressed.connect(_on_tunnel_left_pressed)
	btn_tunnel_right.pressed.connect(_on_tunnel_right_pressed)
	
func _spawn_players(num_humans: int, num_enemies: int):
	players.clear()
	var start_tile = tiles[0]

	# Barvy hráčů (můžeš upravit)
	var human_colors = [
		Color(0.2, 0.6, 1.0),
		Color(0.2, 1.0, 0.4),
		Color(1.0, 0.8, 0.2),
		Color(1.0, 0.3, 0.3),
	]

	var enemy_color = Color(0.5, 0.2, 0.8)

	var positions = [
		Vector3(-0.2, -0.3, -0.2), # hráč 0
		Vector3(0.2, -0.3, -0.2), # hráč 1
		Vector3(-0.1, -0.8,  -0.2), # hráč 2
		Vector3(0.3, -0.8,  -0.2), # hráč 3
	]

	var index_counter = 0

	# LIDŠTÍ HRÁČI
	for i in range(num_humans):
		var p = player_scene.instantiate()
		p.board = self
		p.player_type = p.PlayerType.HUMAN
		p.player_index = index_counter
		p.color = human_colors[i]
		p.current_tile_index = 0

		var base_pos = start_tile.player_spot.global_position
		var offset: Vector3 = positions[index_counter]
		p.global_position = base_pos + offset

		players_root.add_child(p)
		players.append(p)
		index_counter += 1

	# NEPŘÁTELÉ
	for j in range(num_enemies):
		var e = player_scene.instantiate()
		e.board = self
		e.player_type = e.PlayerType.ENEMY
		e.player_index = index_counter
		e.color = enemy_color
		e.current_tile_index = 0

		var base_pos = start_tile.player_spot.global_position
		var offset: Vector3 = positions[index_counter]
		e.global_position = base_pos + offset
		players_root.add_child(e)
		players.append(e)
		index_counter += 1

	current_player_index = 0
	_start_turn()
	
func _start_turn():
	var active_player = players[current_player_index]
	# tady můžeš updatnout UI – zvýraznit aktuálního hráče atd.
	print("Na tahu je hráč: ", current_player_index, " typ: ", active_player.player_type)


func _next_turn():
	current_player_index = (current_player_index + 1) % players.size()
	_start_turn()
	
func _on_dice_pressed():
	var active_player = players[current_player_index]
	if active_player.is_moving:
		return

	var roll = randi_range(1, 6)
	print("Hráč ", current_player_index, " hodil ", roll)

	await active_player.move_steps(roll)
	# on_player_finished_move se zavolá uvnitř Player.move_steps -> tady jen log
	
func on_player_finished_move(player):
	await _check_special_tile(player)
	_next_turn()
	
func _check_special_tile(player) -> void:
	var tile := tiles[player.current_tile_index] as Tile
	if tile == null:
		push_error("Tile na indexu %d nemá Tile skript" % player.current_tile_index)
		return

	match tile.kind:
		Tile.TileKind.LADDER_START:
			await _handle_ladder(player, tile)

		Tile.TileKind.TUNNEL_START:
			await  _handle_tunnel(player, tile)

		_:
			# nic speciálního
			pass
			
func _on_tunnel_left_pressed():
	_tunnel_choice = 0

func _on_tunnel_right_pressed():
	_tunnel_choice = 1
	
func _wait_for_tunnel_choice() -> int:
	_tunnel_choice = -1
	tunnel_panel.visible = true

	# čekáme, dokud hráč neklikne levý/pravý
	while _tunnel_choice == -1:
		await get_tree().process_frame

	tunnel_panel.visible = false
	return _tunnel_choice
			
func _handle_tunnel(player, tile: Tile) -> void:
	if tile.jump_target_index_1 < 0 or tile.jump_target_index_2 < 0:
		push_warning("Tunnel start tile %d nemá oba targety nastavené" % tile.index)
		return

	print("Hráč", player.player_index, "stojí na tunelu", tile.index, "– čekám na volbu", tunnel_left_is_good.get(tile.index, true))

	var choice := await _wait_for_tunnel_choice()
	var target_index: int
	var left_is_good: bool = tunnel_left_is_good.get(tile.index, true)

	if choice == 0:
		target_index = tile.jump_target_index_1 if left_is_good else tile.jump_target_index_2
	else:
		target_index = tile.jump_target_index_2 if left_is_good else tile.jump_target_index_1

	if target_index < 0 or target_index >= tiles.size():
		push_warning("Tunnel target index %d je mimo rozsah" % target_index)
		return

	print("Tunel vede na index", target_index)

	await player.move_to_index(target_index)
	player.current_tile_index = target_index
			
func _handle_ladder(player, tile: Tile) -> void:
	if tile.jump_target_index_1 < 0:
		push_warning("Ladder start tile %d nemá nastavený jump_target_index_1" % tile.index)
		return

	var target_index := tile.jump_target_index_1
	if target_index < 0 or target_index >= tiles.size():
		push_warning("Ladder target index %d je mimo rozsah" % target_index)
		return

	await player.move_to_index(target_index)
	player.current_tile_index = target_index
	
func _on_drop_pressed():
	var active_player = players[current_player_index]
	if active_player.is_moving:
		return

	var current = active_player.current_tile_index
	var row = current / BOARD_WIDTH

	if row == 0:
		print("Hráč je na spodním schodu, nemůže seskočit níž.")
		return

	var col = current % BOARD_WIDTH
	var target_row = row - 1
	var target_index = target_row * BOARD_WIDTH + col  # jednoduchý seskok

	await active_player.move_to_index(target_index)
	active_player.current_tile_index = target_index
	_next_turn()
	
func _on_courage_pressed():
	var active_player = players[current_player_index]
	if active_player.is_moving:
		return

	print("Karta odvahy ještě není implementovaná 🙂")
	# sem později doplníš logiku (např. přidat buff, větší hod kostkou, atd.)
	_next_turn()

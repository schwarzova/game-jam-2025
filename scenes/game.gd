extends Node3D

const BOARD_WIDTH := 10
const BOARD_HEIGHT := 10

const CourageCardManagerIns = preload("res://scripts/cards.gd")

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

@onready var board_camera: Camera3D = $Camera3D
@onready var players_root = $PlayersRoot
@onready var btn_dice = $CanvasLayer/HUD/BottomRightActions/BtnDice
@onready var btn_courage = $CanvasLayer/HUD/BottomRightActions/BtnCourage
@onready var btn_drop = $CanvasLayer/HUD/BottomRightActions/BtnDrop
@onready var tunnel_panel = $CanvasLayer/HUD/TunnelChoice
@onready var btn_tunnel_left = $CanvasLayer/HUD/TunnelChoice/LeftTunnel
@onready var btn_tunnel_right = $CanvasLayer/HUD/TunnelChoice/RightTunnel
@onready var courage_panel = $CanvasLayer/HUD/CourageCardPanel
@onready var courage_title = $CanvasLayer/HUD/CourageCardPanel/CardTitle
@onready var courage_desc  = $CanvasLayer/HUD/CourageCardPanel/CardDescription
@onready var courage_ok    = $CanvasLayer/HUD/CourageCardPanel/BtnOk
@onready var dice_result_label = $CanvasLayer/HUD/BottomRightActions/DiceResultLabel
@onready var end_screen      = $CanvasLayer/HUD/EndScreen
@onready var rank1_label     = $CanvasLayer/HUD/EndScreen/RankContainer/Rank1
@onready var rank2_label     = $CanvasLayer/HUD/EndScreen/RankContainer/Rank2
@onready var rank3_label     = $CanvasLayer/HUD/EndScreen/RankContainer/Rank3
@onready var btn_back_to_menu = $CanvasLayer/HUD/EndScreen/BtnBackToMenu

var _tunnel_choice: int = -1  # -1 = no, 0 = left, 1 = right
var tunnel_left_is_good: Dictionary = {}

var rank: Array = []

var card_manager: CourageCardManagerIns
var _courage_card_ack = false
var is_ui_locked: bool = false

var game_over: bool = false

func _ready() -> void:
	_build_board()
	_setup_special_tiles()
	_setup_ui_signals()
	_spawn_players(2, 2) # třeba default – 2 hráči, 2 nepřátelé
	card_manager = CourageCardManager.new()
	
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
	_make_ladder(5, 23)
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
	courage_ok.pressed.connect(_on_courage_ok_pressed)
	btn_back_to_menu.pressed.connect(_on_back_to_menu_pressed)
	
func _spawn_players(num_humans: int, num_enemies: int):
	players.clear()
	var start_tile = tiles[0]

	# Barvy hráčů (můžeš upravit)
	var colors_belly = [
		Color(0.0, 0.408, 0.742, 1.0),
		Color(0.0, 0.422, 0.133, 1.0),
		Color(0.623, 0.486, 0.0, 1.0),
		Color(0.703, 0.0, 0.105, 1.0),
	]
	
	var colors = [
		Color(0.377, 0.674, 1.0, 1.0),
		Color(0.2, 1.0, 0.4),
		Color(1.0, 0.807, 0.25, 1.0),
		Color(1.0, 0.372, 0.356, 1.0),
	]

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
		p.color = colors[index_counter]
		p.colorBelly = colors_belly[index_counter]
		p.current_tile_index = 0
		p.movement_started.connect(_on_player_movement_started)
		p.movement_finished.connect(_on_player_movement_finished)

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
		e.color = colors[index_counter]
		e.colorBelly = colors_belly[index_counter]
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
	
	if active_player.current_tile_index == 99:
		_next_turn()
		return
	
	active_player.set_on_turn(true)
	# tady můžeš updatnout UI – zvýraznit aktuálního hráče atd.
	print("Na tahu je hráč: ", current_player_index, " typ: ", active_player.player_type)

func _next_turn():
	var active_player = players[current_player_index]
	current_player_index = (current_player_index + 1) % players.size()
	active_player.set_on_turn(false)
	_start_turn()
	
func _on_dice_pressed():
	if is_ui_locked:
		return
		
	var active_player = players[current_player_index]
	if active_player.is_moving:
		return

	var roll = randi_range(1, 6)
	_show_dice_result(roll)
	print("Hráč ", current_player_index, " hodil ", roll)

	await active_player.move_steps(roll)
	# on_player_finished_move se zavolá uvnitř Player.move_steps -> tady jen log
	
func _show_dice_result(roll: int) -> void:
	dice_result_label.text = str(roll)
	await get_tree().create_timer(2.0).timeout
	dice_result_label.text = ""

func _on_player_movement_started(player) -> void:
	# přepnout na kameru daného hráče
	if is_instance_valid(player.follow_camera):
		player.follow_camera.current = true


func _on_player_movement_finished(player) -> void:
	# vrátit zpět pohled na celou hrací plochu
	if is_instance_valid(board_camera):
		board_camera.current = true
	
func on_player_finished_move(player):
	await _check_special_tile(player)
	
	if player.current_tile_index == 99:
		player.is_finished = true 
		rank.append(player)
		
	if rank.size() == 3:
		_finish_game()
		
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
	if is_ui_locked:
		return
		
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
	await _check_special_tile(active_player)
	_next_turn()
	
func _on_courage_ok_pressed():
	_courage_card_ack = true
	
func _show_courage_card(card: Dictionary) -> void:
	is_ui_locked = true
	courage_title.text = str(card["name"])
	courage_desc.text = str(card["description"])
	courage_panel.visible = true
	_courage_card_ack = false

func _wait_for_courage_ok() -> void:
	while not _courage_card_ack:
		await get_tree().process_frame
	courage_panel.visible = false
	is_ui_locked = false
	
func _on_courage_pressed() -> void:
	if is_ui_locked:
		return
		
	var active_player = players[current_player_index]
	if active_player.is_moving:
		return

	var card = card_manager.draw_random()

	_show_courage_card(card)
	await _wait_for_courage_ok()

	await card_manager.apply_card(card, self, active_player)

	_next_turn()
	
func _find_nearest_tile_of_kind(from_index, kinds) -> int:
	var best_index := -1
	var best_dist := 999999

	for i in range(tiles.size()):
		var t = tiles[i]
		if t.kind in kinds:
			var d = abs(i - from_index)
			if d < best_dist:
				best_dist = d
				best_index = i

	return best_index
	
func _get_last_player():
	var worst = null
	var worst_index := 999999

	for p in players:
		if (worst == null or p.current_tile_index < worst_index) and !p.is_finished:
			worst = p
			worst_index = p.current_tile_index

	return worst

func _card_swap_with_last(player) -> void:
	var last = _get_last_player()
	if last == null or last == player:
		print("Žádný jiný poslední hráč k výměně.")
		return

	_swap_players_positions(player, last)
	
func _get_leader_player():
	var best = null
	var best_index := -1

	for p in players:
		if (best == null or p.current_tile_index > best_index) and !p.is_finished:
			best = p
			best_index = p.current_tile_index

	return best

func _swap_players_positions(p1, p2) -> void:
	var idx1 = p1.current_tile_index
	var idx2 = p2.current_tile_index

	# můžeš je klidně jen teleportovat, nebo udělat tweens
	var tmp_pos = p1.global_position
	p1.global_position = p2.global_position
	p2.global_position = tmp_pos

	p1.current_tile_index = idx2
	p2.current_tile_index = idx1

func _card_swap_with_leader(player) -> void:
	var leader = _get_leader_player()
	if leader == null or leader == player:
		print("Žádný jiný leader k výměně.")
		return

	_swap_players_positions(player, leader)

func _finish_game() -> void:
	game_over = true
	is_ui_locked = true

	# schovej běžné herní UI (volitelné)
	$CanvasLayer/HUD/BottomRightActions.visible = false
	end_screen.visible = true

	# Naplnit texty podle rank
	if rank.size() > 0:
		rank1_label.text = "1. místo: Hráč " + str(rank[0].player_index + 1)
	else:
		rank1_label.text = "1. místo: -"

	if rank.size() > 1:
		rank2_label.text = "2. místo: Hráč " + str(rank[1].player_index + 1)
	else:
		rank2_label.text = "2. místo: -"

	if rank.size() > 2:
		rank3_label.text = "3. místo: Hráč " + str(rank[2].player_index + 1)
	else:
		rank3_label.text = "3. místo: -"
		
func _on_back_to_menu_pressed():
	get_tree().reload_current_scene()

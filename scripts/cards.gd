# cards.gd
extends RefCounted
class_name CourageCardManager

enum CardType {
	BACK_TO_START,
	TO_NEAREST_LADDER,
	TO_NEAREST_TUNNEL,
	SWAP_WITH_LEADER,
	SWAP_WITH_LAST,
	MOVE_PLUS_3,
	MOVE_MINUS_3,
	TELEPORT_RANDOM,
	OTHERS_PLUS_5,
	OTHERS_MINUS_5,
	OTHERS_STEP_DOWN,
}

var cards: Array[Dictionary] = [
	{
		"id": CardType.BACK_TO_START,
		"name": "Zpátky na začátek",
		"description": "Padáš až na úplný začátek.",
	},
	{
		"id": CardType.TO_NEAREST_LADDER,
		"name": "Žebřík naděje",
		"description": "Přesune tě na nejbližší žebřík.",
	},
	{
		"id": CardType.TO_NEAREST_TUNNEL,
		"name": "Riskantní tunel",
		"description": "Přesune tě na nejbližší tunel a musíš jím projít.",
	},
	{
		"id": CardType.SWAP_WITH_LEADER,
		"name": "Výměna s lídrem",
		"description": "Vyměníš si pozici s hráčem, který je nejdál.",
	},
	{
		"id": CardType.SWAP_WITH_LAST,
		"name": "Výměna s posledním",
		"description": "Vyměníš si pozici s hráčem, který je nejvíc pozadu.",
	},
	{
		"id": CardType.MOVE_PLUS_3,
		"name": "Vpřed o 3",
		"description": "Jdeš o tři pole dopředu.",
	},
	{
		"id": CardType.MOVE_MINUS_3,
		"name": "Vzad o 3",
		"description": "Jdeš o tři pole dozadu.",
	},
	{
		"id": CardType.TELEPORT_RANDOM,
		"name": "Chaotický teleport",
		"description": "Teleportuje tě na náhodné pole.",
	},
	{
		"id": CardType.OTHERS_PLUS_5,
		"name": "Ostatní kupředu",
		"description": "Všichni ostatní hráči jdou o 5 polí dopředu.",
	},
	{
		"id": CardType.OTHERS_MINUS_5,
		"name": "Ostatní zpět",
		"description": "Všichni ostatní hráči jdou o 5 polí dozadu.",
	},
	{
		"id": CardType.OTHERS_STEP_DOWN,
		"name": "Hromadný seskok",
		"description": "Všichni ostatní seskočí o jeden schod dolů.",
	},
]

func draw_random() -> Dictionary:
	var randomIndex = randf_range(0, cards.size())
	return cards[randomIndex]

# Game je tvoje Game.gd (má tiles, players, helper funkce)
func apply_card(card: Dictionary, game, player) -> void:
	var card_id: int = card["id"]

	match card_id:
		CardType.BACK_TO_START:
			await _card_back_to_start(game, player)
		CardType.TO_NEAREST_LADDER:
			await _card_to_nearest_ladder(game, player)
		CardType.TO_NEAREST_TUNNEL:
			await _card_to_nearest_tunnel(game, player)
		CardType.SWAP_WITH_LEADER:
			await _card_swap_with_leader(game, player)
		CardType.SWAP_WITH_LAST:
			await _card_swap_with_last(game, player)
		CardType.MOVE_PLUS_3:
			await _card_move_relative(game, player, 3)
		CardType.MOVE_MINUS_3:
			await _card_move_relative(game, player, -3)
		CardType.TELEPORT_RANDOM:
			await _card_teleport_random(game, player)
		CardType.OTHERS_PLUS_5:
			await _card_others_move_relative(game, player, 5)
		CardType.OTHERS_MINUS_5:
			await _card_others_move_relative(game, player, -5)
		CardType.OTHERS_STEP_DOWN:
			await _card_others_step_down(game, player)
		_:
			print("Neznámý typ karty:", card_id)
			
const START_INDEX := 0

func _card_back_to_start(game, player) -> void:
	await player.move_to_index(START_INDEX)
	player.current_tile_index = START_INDEX

func _card_to_nearest_ladder(game, player) -> void:
	var from = player.current_tile_index
	var target_index = game._find_nearest_tile_of_kind(
		from,
		[Tile.TileKind.LADDER_START]
	)
	if target_index == -1:
		print("Žádný žebřík.")
		return

	await player.move_to_index(target_index)
	player.current_tile_index = target_index

	var tile: Tile = game.tiles[target_index]
	await game._handle_ladder(player, tile)

func _card_to_nearest_tunnel(game, player) -> void:
	var from = player.current_tile_index
	var target_index = game._find_nearest_tile_of_kind(
		from,
		[Tile.TileKind.TUNNEL_START]
	)
	if target_index == -1:
		print("Žádný tunel.")
		return

	await player.move_to_index(target_index)
	player.current_tile_index = target_index

	var tile: Tile = game.tiles[target_index]
	await game._handle_tunnel(player, tile)

func _card_swap_with_leader(game, player) -> void:
	var leader = game._get_leader_player()
	if leader == null or leader == player:
		return
	game._swap_players_positions(player, leader)

func _card_swap_with_last(game, player) -> void:
	var last = game._get_last_player()
	if last == null or last == player:
		return
	game._swap_players_positions(player, last)

func _card_move_relative(game, player, delta: int) -> void:
	var tiles_count = game.tiles.size()
	var current = player.current_tile_index
	var target = clamp(current + delta, 0, tiles_count - 1)

	if target == current:
		return

	await player.move_to_index(target)
	player.current_tile_index = target

func _card_teleport_random(game, player) -> void:
	var tiles_count = game.tiles.size()
	if tiles_count <= 1:
		return

	var target := randi_range(0, tiles_count - 1)

	# chceš-li se vyhnout stejné pozici:
	if target == player.current_tile_index and tiles_count > 1:
		target = (target + 1) % tiles_count

	await player.move_to_index(target)
	player.current_tile_index = target

func _card_others_move_relative(game, current_player, delta: int) -> void:
	var tiles_count = game.tiles.size()

	for p in game.players:
		if p == current_player or p.is_finished:
			continue

		var current = p.current_tile_index
		var target = clamp(current + delta, 0, tiles_count - 1)

		if target == current:
			continue

		await p.move_to_index(target)
		p.current_tile_index = target

func _card_others_step_down(game, current_player) -> void:
	var w: int = game.BOARD_WIDTH

	for p in game.players:
		if p == current_player or p.is_finished:
			continue

		var idx = p.current_tile_index
		var row = idx / w
		var col = idx % w

		if row == 0:
			# už je na nejnižším schodu, nejde seskočit
			continue

		var target_index = (row - 1) * w + col

		await p.move_to_index(target_index)
		p.current_tile_index = target_index
		await game._check_special_tile(p)

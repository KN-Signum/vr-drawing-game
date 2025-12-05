extends Control

@export var info_display_time: float = 5.0
var current_screen = "info"  # "info" lub "menu"
var can_continue: bool = false

@onready var info_screen = $CenterContainer/Panel/InnerPanel/MarginContainer/InfoScreen
@onready var menu_screen = $CenterContainer/Panel/InnerPanel/MarginContainer/MenuScreen

func _ready():
	# Add to "menu" group for remote control
	add_to_group("menu")
	
	# Pokaż ekran informacyjny, ukryj menu
	if info_screen:
		info_screen.visible = true
	if menu_screen:
		menu_screen.visible = false
	
	# Czekaj kilka sekund przed umożliwieniem przejścia dalej
	await get_tree().create_timer(info_display_time).timeout
	can_continue = true
	
	# Pokaż informację że można kontynuować
	var info_instruction = get_node_or_null("CenterContainer/Panel/InnerPanel/MarginContainer/InfoScreen/VBoxContainer/InfoInstruction")
	if info_instruction:
		info_instruction.visible = true
	
	# Notify WebSocket clients that menu is ready
	_notify_menu_state()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		if current_screen == "info" and can_continue:
			show_menu_screen()
		elif current_screen == "menu":
			start_game()

# Called remotely via WebSocket
func remote_next():
	if current_screen == "info" and can_continue:
		show_menu_screen()
	elif current_screen == "menu":
		# Already on menu, ignore or could cycle through games
		pass

# Called remotely via WebSocket
func remote_start_game_draw():
	if current_screen == "menu":
		start_game("draw")

func show_menu_screen():
	current_screen = "menu"
	if info_screen:
		info_screen.visible = false
	if menu_screen:
		menu_screen.visible = true
	_notify_menu_state()
	_send_available_games()

func start_game(game_name: String = "draw"):
	print("Uruchamianie gry: %s" % game_name)
	
	# Notify dashboard that game is starting with available actions
	var ws_streamer = get_node_or_null("/root/WebSocketStreamer")
	if ws_streamer and ws_streamer.has_method("_send_json"):
		var game_data = {
			"type": "game_started",
			"game": game_name,
			"actions": []
		}
		
		# Add game-specific actions
		match game_name:
			"draw":
				game_data["actions"] = [
					{"id": "save_canvas", "name": "Zapisz rysunek", "description": "Zapisuje bieżący stan canvas"},
					{"id": "clear_canvas", "name": "Wyczyść canvas", "description": "Czyści cały canvas"}
				]
		
		ws_streamer._send_json(game_data)
	
	# Load appropriate scene based on game name
	match game_name:
		"draw":
			get_tree().change_scene_to_file("res://src/world.tscn")
		_:
			print("Unknown game: %s" % game_name)

func _notify_menu_state():
	# Find WebSocketStreamer and notify about state change
	var ws_streamer = get_node_or_null("/root/WebSocketStreamer")
	if ws_streamer and ws_streamer.has_method("_send_json"):
		ws_streamer._send_json({
			"type": "menu_state",
			"screen": current_screen,
			"can_continue": can_continue
		})

func _send_available_games():
	# Send list of available games to dashboard
	var ws_streamer = get_node_or_null("/root/WebSocketStreamer")
	if ws_streamer and ws_streamer.has_method("_send_json"):
		ws_streamer._send_json({
			"type": "available_games",
			"games": [
				{"id": "draw", "name": "Drawing Game", "description": "Gra rysunkowa"}
				# Tutaj można dodać więcej gier w przyszłości
			]
		})

extends Control

@export var info_display_time: float = 5.0
var current_screen = "info"  # "info" lub "menu"
var can_continue: bool = false

# Menu selection
var selected_game_index: int = 0
var game_options = [
	{"id": "draw", "name": "Drawing Game", "label_name": "Game1"},
	{"id": "forest_walk", "name": "Spacer w lesie", "label_name": "Game2"}
]

@onready var info_screen = $CenterContainer/Panel/InnerPanel/MarginContainer/InfoScreen
@onready var menu_screen = $CenterContainer/Panel/InnerPanel/MarginContainer/MenuScreen

func _ready():
	# Add to "menu" group for remote control
	add_to_group("menu")
	
	# Display IP addresses
	_display_ip_addresses()
	
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
			start_selected_game()
	
	if current_screen == "menu":
		if event.is_action_pressed("ui_up"):
			selected_game_index = (selected_game_index - 1) % game_options.size()
			_update_game_selection()
		elif event.is_action_pressed("ui_down"):
			selected_game_index = (selected_game_index + 1) % game_options.size()
			_update_game_selection()

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

# Called remotely via WebSocket
func remote_start_game_forest_walk():
	if current_screen == "menu":
		start_game("forest_walk")

func show_menu_screen():
	current_screen = "menu"
	if info_screen:
		info_screen.visible = false
	if menu_screen:
		menu_screen.visible = true
	selected_game_index = 0
	_update_game_selection()
	_notify_menu_state()
	_send_available_games()

func _update_game_selection():
	# Update visual indicators for all game options
	for i in range(game_options.size()):
		var label_path = "CenterContainer/Panel/InnerPanel/MarginContainer/MenuScreen/GamesContainer/" + game_options[i]["label_name"]
		var label = get_node_or_null(label_path)
		if label:
			if i == selected_game_index:
				label.text = "► " + game_options[i]["name"] + " ◄"
				label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05, 1))  # Darker when selected
			else:
				label.text = game_options[i]["name"]
				label.add_theme_color_override("font_color", Color(0.3, 0.2, 0.15, 1))  # Normal color

func start_selected_game():
	var selected_game = game_options[selected_game_index]
	start_game(selected_game["id"])

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
					{"id": "clear_canvas", "name": "Wyczyść canvas", "description": "Czyści cały canvas"},
					{"id": "reset_butterfly", "name": "Resetuj motylka", "description": "Przywraca szablon motylka (prawa strona)"}
				]
		
		ws_streamer._send_json(game_data)
	
	# Load appropriate scene based on game name
	match game_name:
		"draw":
			get_tree().change_scene_to_file("res://src/world.tscn")
		"forest_walk":
			# TODO: Change to forest scene when ready
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
				{"id": "draw", "name": "Drawing Game", "description": "Gra rysunkowa"},
				{"id": "forest_walk", "name": "Spacer w lesie", "description": "Spacer po wirtualnym lesie"}
			]
		})

func _display_ip_addresses():
	var ip_label = get_node_or_null("IPAddressLabel")
	if not ip_label:
		return
	
	var local_ips = IP.get_local_addresses()
	var ip_text = "WebSocket Server:\n"
	var found_ip = false
	
	for ip in local_ips:
		# Filter out localhost and IPv6
		if not ip.begins_with("127.") and not ip.contains(":"):
			ip_text += "ws://%s:9001\n" % ip
			found_ip = true
	
	if not found_ip:
		ip_text += "No network connection"
	
	ip_label.text = ip_text

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
func remote_start_game():
	if current_screen == "menu":
		start_game()

func show_menu_screen():
	current_screen = "menu"
	if info_screen:
		info_screen.visible = false
	if menu_screen:
		menu_screen.visible = true
	_notify_menu_state()

func start_game():
	print("Uruchamianie Drawing Game...")
	get_tree().change_scene_to_file("res://src/world.tscn")

func _notify_menu_state():
	# Find WebSocketStreamer and notify about state change
	var ws_streamer = get_node_or_null("/root/WebSocketStreamer")
	if ws_streamer and ws_streamer.has_method("_send_json"):
		ws_streamer._send_json({
			"type": "menu_state",
			"screen": current_screen,
			"can_continue": can_continue
		})

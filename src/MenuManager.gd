extends Control

@export var info_display_time: float = 5.0
var current_screen = "info"  # "info" lub "menu"
var can_continue: bool = false

@onready var info_screen = $CenterContainer/Panel/InnerPanel/MarginContainer/InfoScreen
@onready var menu_screen = $CenterContainer/Panel/InnerPanel/MarginContainer/MenuScreen

func _ready():
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

func _input(event):
	if event.is_action_pressed("ui_accept"):
		if current_screen == "info" and can_continue:
			show_menu_screen()
		elif current_screen == "menu":
			start_game()

func show_menu_screen():
	current_screen = "menu"
	if info_screen:
		info_screen.visible = false
	if menu_screen:
		menu_screen.visible = true

func start_game():
	print("Uruchamianie Drawing Game...")
	get_tree().change_scene_to_file("res://src/world.tscn")

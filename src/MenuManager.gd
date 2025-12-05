extends Control

@export var title_display_time: float = 3.0
var can_start: bool = false

func _ready():
	# Ukryj instrukcję na początku
	var instruction_label = get_node_or_null("CenterContainer/Panel/InnerPanel/MarginContainer/VBoxContainer/InstructionLabel")
	if instruction_label:
		instruction_label.visible = false
	
	# Czekaj 3 sekundy przed umożliwieniem rozpoczęcia gry
	await get_tree().create_timer(title_display_time).timeout
	can_start = true
	
	if instruction_label:
		instruction_label.visible = true

func _input(event):
	if can_start and event.is_action_pressed("ui_accept"):
		start_game()

func start_game():
	print("Uruchamianie Drawing Game...")
	get_tree().change_scene_to_file("res://src/world.tscn")

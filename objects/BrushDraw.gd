# BrushDraw.gd (Final version)
extends Node3D

@export var raycast_path: NodePath = "DrawRay"
var draw_ray: RayCast3D
var current_canvas: StaticBody3D = null 
var is_drawing: bool = false 

func _ready():
	draw_ray = get_node(raycast_path) as RayCast3D
	if not draw_ray:
		push_error("RayCast3D node not found at path: " + str(raycast_path))

func _physics_process(delta):
	if draw_ray.is_colliding():
		var collider = draw_ray.get_collider()
		
		if collider is StaticBody3D and collider.is_in_group("canvas"):
			var canvas_body = collider as StaticBody3D
			var is_new_stroke = false

			if not is_drawing:
				is_drawing = true
				current_canvas = canvas_body
				is_new_stroke = true # This is the start of a new line

			# 🛑 CRITICAL FIX: Use .call() and pass TWO arguments
			if current_canvas.has_method("draw_at_world_pos"):
				current_canvas.call("draw_at_world_pos", draw_ray.get_collision_point(), is_new_stroke)
			else:
				push_error("EaselDraw.gd is not attached or failed to load.")

		else:
			if is_drawing:
				stop_drawing_on_canvas()

	else:
		if is_drawing:
			stop_drawing_on_canvas()
			
func stop_drawing_on_canvas():
	if current_canvas and current_canvas.has_method("stop_drawing"):
		current_canvas.call("stop_drawing")
	is_drawing = false
	current_canvas = null

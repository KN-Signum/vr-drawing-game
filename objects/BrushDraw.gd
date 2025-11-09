# BrushDraw.gd (Final version)
extends Node3D

@export var raycast_path: NodePath = "DrawRay"
@export var visual_ray_path: NodePath = "VisualRay"
@export var ray_color_normal: Color = Color.CYAN
@export var ray_color_hitting: Color = Color.GREEN
@export var ray_color_drawing: Color = Color.RED

# Debug settings
@export var enable_debug: bool = true

var draw_ray: RayCast3D
var visual_ray: MeshInstance3D
var current_canvas: StaticBody3D = null 
var is_drawing: bool = false 

func _ready():
	draw_ray = get_node(raycast_path) as RayCast3D
	if not draw_ray:
		push_error("RayCast3D node not found at path: " + str(raycast_path))
	
	visual_ray = get_node(visual_ray_path) as MeshInstance3D
	if not visual_ray:
		push_error("VisualRay MeshInstance3D node not found at path: " + str(visual_ray_path))
	
	setup_visual_ray()

func _physics_process(delta):
	update_visual_ray()
	
	if draw_ray.is_colliding():
		var collider = draw_ray.get_collider()
		var collision_point = draw_ray.get_collision_point()
		
		if enable_debug:
			print("=== BRUSH DEBUG ===")
			print("Brush position: ", global_position)
			print("Ray collision point: ", collision_point)
			print("Collider: ", collider)
			if collider:
				print("Collider groups: ", collider.get_groups())
			print("===================")
		
		if collider is StaticBody3D and collider.is_in_group("canvas"):
			var canvas_body = collider as StaticBody3D
			var is_new_stroke = false

			if not is_drawing:
				is_drawing = true
				current_canvas = canvas_body
				is_new_stroke = true # This is the start of a new line
				if enable_debug:
					print("*** STARTING NEW STROKE ON VALID CANVAS ***")

			# 🛑 CRITICAL FIX: Use .call() and pass TWO arguments
			if current_canvas.has_method("draw_at_world_pos"):
				current_canvas.call("draw_at_world_pos", collision_point, is_new_stroke)
			else:
				push_error("EaselDraw.gd is not attached or failed to load.")

		else:
			if enable_debug and collider:
				print("*** HITTING NON-CANVAS OBJECT: ", collider, " Groups: ", collider.get_groups())
			if is_drawing:
				if enable_debug:
					print("*** STOPPING DRAWING (not on canvas) ***")
				stop_drawing_on_canvas()

	else:
		if is_drawing:
			if enable_debug:
				print("*** STOPPING DRAWING (no collision) ***")
			stop_drawing_on_canvas()
			
func stop_drawing_on_canvas():
	if current_canvas and current_canvas.has_method("stop_drawing"):
		current_canvas.call("stop_drawing")
	is_drawing = false
	current_canvas = null

func setup_visual_ray():
	if not visual_ray:
		return
	
	# Create a cylinder mesh for the ray
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = 0.002  # Very thin ray
	cylinder_mesh.bottom_radius = 0.002
	cylinder_mesh.height = 1.0  # Will be scaled based on ray length
	
	visual_ray.mesh = cylinder_mesh
	
	# Create material for the ray
	var material = StandardMaterial3D.new()
	material.flags_unshaded = true  # Always visible, not affected by lighting
	material.flags_do_not_receive_shadows = true
	material.flags_disable_ambient_light = true
	material.emission_enabled = true
	material.emission = ray_color_normal
	material.albedo_color = ray_color_normal
	
	visual_ray.material_override = material

func update_visual_ray():
	if not visual_ray or not draw_ray:
		return
	
	var ray_length = 0.3  # Default short ray length
	var material = visual_ray.material_override as StandardMaterial3D
	
	if draw_ray.is_colliding():
		var collision_point = draw_ray.get_collision_point()
		var ray_origin = draw_ray.global_position
		ray_length = ray_origin.distance_to(collision_point)
		
		# Change color based on what we're hitting
		var collider = draw_ray.get_collider()
		if collider is StaticBody3D and collider.is_in_group("canvas"):
			if is_drawing:
				material.emission = ray_color_drawing
				material.albedo_color = ray_color_drawing
			else:
				material.emission = ray_color_hitting
				material.albedo_color = ray_color_hitting
		else:
			material.emission = ray_color_normal
			material.albedo_color = ray_color_normal
	else:
		# No collision, show normal colored ray
		material.emission = ray_color_normal
		material.albedo_color = ray_color_normal
	
	# Update ray scale and position
	visual_ray.scale.y = ray_length
	visual_ray.position.y = ray_length * 0.5  # Center the cylinder on the ray

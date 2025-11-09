# BrushDraw.gd (Final version)
extends Node3D

@export var raycast_path: NodePath = "DrawRay"
@export var visual_ray_path: NodePath = "VisualRay"
@export var bristles_path: NodePath = "Bristles"
@export var ray_color_normal: Color = Color.CYAN
@export var ray_color_hitting: Color = Color.GREEN
@export var ray_color_drawing: Color = Color.RED

# Debug settings
@export var enable_debug: bool = true

var draw_ray: RayCast3D
var visual_ray: MeshInstance3D
var bristles: MeshInstance3D
var current_canvas: StaticBody3D = null 
var is_drawing: bool = false
var current_color: Color = Color.BLACK 

func _ready():
	draw_ray = get_node(raycast_path) as RayCast3D
	if not draw_ray:
		push_error("RayCast3D node not found at path: " + str(raycast_path))
	
	visual_ray = get_node(visual_ray_path) as MeshInstance3D
	if visual_ray:
		visual_ray.visible = false  # Hide the visual ray indicator
	
	bristles = get_node(bristles_path) as MeshInstance3D
	if not bristles:
		push_error("Bristles MeshInstance3D not found at path: " + str(bristles_path))

func _physics_process(delta):
	# update_visual_ray()  # Disabled - no visual ray needed
	
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
		
		# Check if hitting a color swatch
		if collider is StaticBody3D and collider.is_in_group("color_swatch"):
			print("*** HIT COLOR SWATCH: ", collider.name)
			var palette = collider.get_parent()
			if palette and palette.has_method("get_color_from_body"):
				var new_color = palette.get_color_from_body(collider)
				print("*** CHANGING COLOR TO: ", new_color)
				change_brush_color(new_color)
			else:
				print("*** PALETTE NOT FOUND OR NO METHOD")
			return  # Don't draw on palette
		
		if collider is StaticBody3D and collider.is_in_group("canvas"):
			var canvas_body = collider as StaticBody3D
			var is_new_stroke = false

			if not is_drawing:
				is_drawing = true
				current_canvas = canvas_body
				is_new_stroke = true # This is the start of a new line
				if enable_debug:
					print("*** STARTING NEW STROKE ON VALID CANVAS ***")

			# Pass collision point, new stroke flag, and current color to canvas
			if current_canvas.has_method("draw_at_world_pos"):
				current_canvas.call("draw_at_world_pos", collision_point, is_new_stroke, current_color)
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
	
	var ray_length = 0.05  # Default ray length (matches bristle length)
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
	
	# Update ray scale - keep the visual ray at its original position (0.07 from bristle tip)
	# The cylinder extends in +Y direction from the bristle tip
	visual_ray.scale.y = ray_length

func change_brush_color(new_color: Color):
	current_color = new_color
	print("*** CHANGE_BRUSH_COLOR CALLED with: ", new_color)
	
	# Change bristle color
	if bristles:
		print("*** Bristles found: ", bristles)
		var material = bristles.get_active_material(0) as StandardMaterial3D
		print("*** Current material: ", material)
		if material:
			# Create a new material instance to avoid modifying the shared resource
			var new_material = material.duplicate()
			new_material.albedo_color = new_color
			bristles.set_surface_override_material(0, new_material)
			print("*** Bristle color changed successfully!")
		else:
			print("*** ERROR: No material found on bristles")
	else:
		print("*** ERROR: Bristles not found!")
	
	# Update canvas drawing color
	# This will be used when drawing on the canvas
	print("Brush color changed to: ", new_color)

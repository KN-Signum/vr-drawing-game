# EaselDraw.gd (Final version)
extends StaticBody3D

@export var viewport_path: NodePath = "../../CanvasViewport"
# Change this path to point to the PAINTER node
@export var painter_path: NodePath = "../../CanvasViewport/Painter2D" 

@export var draw_color: Color = Color.BLACK
@export var draw_width: float = 8.0

# Debug settings
@export var enable_debug: bool = true
@export var show_debug_spheres: bool = true

var painter_2d: Node2D # Variable now holds the Painter2D node
var canvas_size: Vector2
var debug_spheres: Array = []

func _ready():
	# Find the Painter2D node with the CanvasPainter script
	painter_2d = get_node(painter_path) as Node2D
	
	if painter_2d:
		# The SubViewport is the Painter's parent
		var canvas_viewport = painter_2d.get_parent() as SubViewport

		if canvas_viewport and painter_2d.has_method("add_draw_point"):
			# Set drawing properties on the painter
			painter_2d.draw_color = draw_color
			painter_2d.draw_width = draw_width
			canvas_size = canvas_viewport.size
		else:
			push_error("Painter2D found, but CanvasPainter.gd script is missing or invalid.")
			painter_2d = null # Invalidate to prevent further errors
	else:
		push_error("Error: Painter2D not found at path: " + str(painter_path))

# Function called by the brush on contact
func draw_at_world_pos(world_pos: Vector3, is_first_contact: bool):
	if not painter_2d:
		return 

	# 1. Convert 3D world position to local 3D position on the canvas
	var local_pos = to_local(world_pos)
	
	# 2. The canvas is a plane in local space. Since it's the XZ plane (rotated):
	# - X axis = horizontal on canvas (left-right)
	# - Z axis = vertical on canvas (up-down)
	# - Y axis = depth (perpendicular to canvas surface)
	# The BoxShape3D has size Vector3(2, 1, 2) where X=2 and Z=2 define the drawing area
	
	# 3. Convert 3D to 2D normalized coordinate (0-1)
	# Map from local X [-1, 1] to normalized [0, 1]
	var normalized_x = (local_pos.x + 1.0) / 2.0
	# Map from local Z [-1, 1] to normalized [0, 1] (Z is the vertical axis on the rotated easel)
	# Note: Z increases upward, so we add 1.0 (not subtract from 1.0)
	var normalized_y = (local_pos.z + 1.0) / 2.0
	
	# 4. Clamp normalized coordinates to valid range (0-1)
	normalized_x = clamp(normalized_x, 0.0, 1.0)
	normalized_y = clamp(normalized_y, 0.0, 1.0)
	
	# 5. Convert normalized coordinate to pixel coordinate (using the viewport size)
	# Note: We assume the SubViewport's size is set correctly in the Inspector (e.g., 1024x1024)
	if canvas_size == Vector2.ZERO: return
	
	var current_draw_pos = Vector2(normalized_x, normalized_y) * canvas_size
	
	# DEBUG: Print coordinate transformation info
	if enable_debug:
		print("=== DRAWING DEBUG ===")
		print("World Position: ", world_pos)
		print("Local Position: ", local_pos)
		print("Local X: %.3f (horizontal, canvas range: -1 to +1)" % local_pos.x)
		print("Local Y: %.3f (depth into canvas)" % local_pos.y)
		print("Local Z: %.3f (vertical, canvas range: -1 to +1)" % local_pos.z)
		print("Normalized X: %.3f, Y: %.3f (0-1 range)" % [normalized_x, normalized_y])
		print("Canvas Size: ", canvas_size)
		print("Final 2D Position: ", current_draw_pos)
		print("Point in canvas bounds: ", (current_draw_pos.x >= 0 and current_draw_pos.x <= canvas_size.x and current_draw_pos.y >= 0 and current_draw_pos.y <= canvas_size.y))
		print("=====================")
	
	# Add debug sphere at world position
	if show_debug_spheres:
		create_debug_sphere(world_pos)
	
	# 4. Send the point to the painter script for drawing
	painter_2d.add_draw_point(current_draw_pos, is_first_contact)
	
func stop_drawing():
	# Send a new stroke instruction to the painter to lift the brush
	if painter_2d and painter_2d.has_method("add_draw_point"):
		painter_2d.add_draw_point(Vector2.ZERO, true) # New stroke starts after this

func create_debug_sphere(world_pos: Vector3):
	# Create a small sphere to visualize where the brush is touching
	var sphere = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.02
	sphere_mesh.height = 0.04
	
	var material = StandardMaterial3D.new()
	material.flags_unshaded = true
	material.emission_enabled = true
	material.emission = Color.YELLOW
	material.albedo_color = Color.YELLOW
	
	sphere.mesh = sphere_mesh
	sphere.material_override = material
	sphere.global_position = world_pos
	
	# Add to scene
	get_tree().current_scene.add_child(sphere)
	debug_spheres.append(sphere)
	
	# Clean up old spheres (keep only last 10)
	if debug_spheres.size() > 10:
		var old_sphere = debug_spheres.pop_front()
		if old_sphere and is_instance_valid(old_sphere):
			old_sphere.queue_free()

func clear_debug_spheres():
	for sphere in debug_spheres:
		if sphere and is_instance_valid(sphere):
			sphere.queue_free()
	debug_spheres.clear()

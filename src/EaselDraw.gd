# EaselDraw.gd (Final version)
extends StaticBody3D

@export var viewport_path: NodePath = "../../CanvasViewport"
# Change this path to point to the PAINTER node
@export var painter_path: NodePath = "../../CanvasViewport/Painter2D" 

@export var draw_color: Color = Color.BLACK
@export var draw_width: float = 8.0

var painter_2d: Node2D # Variable now holds the Painter2D node
var canvas_size: Vector2

# --- IMPORTANT: ADJUST THESE VALUES ---
var uv_x_range: float = 1.5 
var uv_y_range: float = 2.0
# -------------------------------------

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
	
	# 2. Convert 3D to 2D normalized coordinate (0-1)
	var normalized_x = (local_pos.x / uv_x_range) + 0.5 
	var normalized_y = 1.0 - ((local_pos.y / uv_y_range) + 0.5)
	
	# 3. Convert normalized coordinate to pixel coordinate (using the viewport size)
	# Note: We assume the SubViewport's size is set correctly in the Inspector (e.g., 1024x1024)
	if canvas_size == Vector2.ZERO: return
	var current_draw_pos = Vector2(normalized_x, normalized_y) * canvas_size
	
	# 4. Send the point to the painter script for drawing
	painter_2d.add_draw_point(current_draw_pos, is_first_contact)
	
func stop_drawing():
	# Send a new stroke instruction to the painter to lift the brush
	if painter_2d and painter_2d.has_method("add_draw_point"):
		painter_2d.add_draw_point(Vector2.ZERO, true) # New stroke starts after this

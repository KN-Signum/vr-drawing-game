# CanvasPainter.gd (Attach to the Painter2D node)
extends Node2D

var draw_points: Array = []
var draw_colors: Array = []  # Store color for each point
var draw_color: Color = Color.BLACK
var draw_width: float = 8.0

# Debug settings
@export var enable_debug: bool = false
@export var show_canvas_bounds: bool = false

func _ready():
	# Add to draw_game group for remote control
	add_to_group("draw_game")
	
	# Pre-draw left half of butterfly
	draw_butterfly_left_half()

func draw_butterfly_left_half():
	var viewport = get_parent() as SubViewport
	var canvas_size = viewport.size if viewport else Vector2(1024, 1024)
	var center_x = canvas_size.x * 0.5
	var center_y = canvas_size.y * 0.5
	var scale = 2.0 
	
	# Left wing outline (upper part) - rotated 180 degrees (now points down on left)
	var left_wing_upper = [
		Vector2(center_x - 50 * scale, center_y),
		Vector2(center_x - 120 * scale, center_y + 80),
		Vector2(center_x - 140 * scale, center_y + 150),
		Vector2(center_x - 120 * scale, center_y + 200),
		Vector2(center_x - 80 * scale, center_y + 220),
		Vector2(center_x - 20 * scale, center_y + 210),
		Vector2(center_x + 10 * scale, center_y + 180),
		Vector2(center_x + 20 * scale, center_y + 140)
	]
	
	# Left wing outline (lower part) - rotated 180 degrees (now points up on left)
	var left_wing_lower = [
		Vector2(center_x + 20 * scale, center_y + 140),
		Vector2(center_x + 60 * scale, center_y + 120),
		Vector2(center_x + 120 * scale, center_y + 130),
		Vector2(center_x + 160 * scale, center_y + 120),
		Vector2(center_x + 180 * scale, center_y + 90),
		Vector2(center_x + 170 * scale, center_y + 50),
		Vector2(center_x + 130 * scale, center_y + 20),
		Vector2(center_x + 80 * scale, center_y)
	]
	
	# Body (left side) - now horizontal pointing right
	var body_left = [
		Vector2(center_x - 80 * scale, center_y),
		Vector2(center_x - 50 * scale, center_y),
		Vector2(center_x, center_y),
		Vector2(center_x + 50 * scale, center_y),
		Vector2(center_x + 100 * scale, center_y)
	]
	
	# Add upper wing
	draw_points.append(null)
	draw_colors.append(null)
	for point in left_wing_upper:
		draw_points.append(point)
		draw_colors.append(Color.BLACK)
	
	# Add lower wing
	draw_points.append(null)
	draw_colors.append(null)
	for point in left_wing_lower:
		draw_points.append(point)
		draw_colors.append(Color.BLACK)
	
	# Add body
	draw_points.append(null)
	draw_colors.append(null)
	for point in body_left:
		draw_points.append(point)
		draw_colors.append(Color.BLACK)
	
	# Add some decorative curves on the wing - rotated 180 degrees
	var wing_detail = [
		Vector2(center_x - 100 * scale, center_y + 150),
		Vector2(center_x - 80 * scale, center_y + 130),
		Vector2(center_x - 50 * scale, center_y + 120)
	]
	
	draw_points.append(null)
	draw_colors.append(null)
	for point in wing_detail:
		draw_points.append(point)
		draw_colors.append(Color.BLACK)

# Function called by the Easel to add new points
func add_draw_point(point: Vector2, is_new_stroke: bool, color: Color = Color.BLACK):
	if is_new_stroke:
		# Separate the strokes by adding a null entry
		draw_points.append(null)
		draw_colors.append(null)
	
	draw_points.append(point)
	draw_colors.append(color)
	
	# Request a redraw to update the texture. Node2D inherits CanvasItem.
	queue_redraw() # <- Error Fixed

func _draw():
	# Show canvas bounds for debugging
	if show_canvas_bounds:
		var viewport = get_parent() as SubViewport
		var canvas_size = viewport.size if viewport else Vector2(1024, 1024)
		
		# Draw canvas border
		draw_rect(Rect2(Vector2.ZERO, canvas_size), Color.RED, false, 4.0)
		
		# Draw center crosshair
		var center = canvas_size * 0.5
		draw_line(Vector2(center.x - 50, center.y), Vector2(center.x + 50, center.y), Color.GREEN, 2.0)
		draw_line(Vector2(center.x, center.y - 50), Vector2(center.x, center.y + 50), Color.GREEN, 2.0)
		
		# Draw grid lines
		for i in range(0, int(canvas_size.x), 100):
			draw_line(Vector2(i, 0), Vector2(i, canvas_size.y), Color.GRAY, 1.0)
		for i in range(0, int(canvas_size.y), 100):
			draw_line(Vector2(0, i), Vector2(canvas_size.x, i), Color.GRAY, 1.0)
	
	# This function is the ONLY place Godot allows drawing.
	var last_point: Vector2 = Vector2.INF
	var last_color: Color = draw_color
	
	for i in range(draw_points.size()):
		var point = draw_points[i]
		var color = draw_colors[i] if i < draw_colors.size() and draw_colors[i] != null else draw_color
		
		if point == null:
			# Start of a new stroke
			last_point = Vector2.INF
			continue
		
		if last_point == Vector2.INF:
			# Initialize the stroke
			last_point = point
			last_color = color
		else:
			# draw_line is available on Node2D.
			draw_line(last_point, point, last_color, draw_width)
			last_point = point
			last_color = color

# Remote control functions called via WebSocket
func remote_clear_canvas():
	print("Clearing canvas via remote control")
	draw_points.clear()
	draw_colors.clear()
	queue_redraw()
	_notify_action_completed("clear_canvas")

func remote_save_canvas():
	print("Sending canvas image to dashboard")
	var success = send_canvas_to_dashboard()
	if not success:
		_notify_action_completed("save_canvas", false)

func send_canvas_to_dashboard() -> bool:
	# Get the viewport and capture the image
	var viewport = get_parent() as SubViewport
	if not viewport:
		push_error("Cannot save: Viewport not found")
		return false
	
	# Get the rendered image
	var img = viewport.get_texture().get_image()
	
	# Convert to PNG bytes
	var png_data = img.save_png_to_buffer()
	
	# Encode to base64 for JSON transmission
	var base64_data = Marshalls.raw_to_base64(png_data)
	
	# Generate timestamp
	var timestamp = Time.get_unix_time_from_system()
	
	# Send via WebSocket
	var ws_streamer = get_node_or_null("/root/WebSocketStreamer")
	if ws_streamer and ws_streamer.has_method("_send_json"):
		ws_streamer._send_json({
			"type": "canvas_image",
			"action": "save_canvas",
			"image_base64": base64_data,
			"format": "png",
			"width": img.get_width(),
			"height": img.get_height(),
			"timestamp": timestamp
		})
		print("Canvas image sent to dashboard (%d bytes)" % png_data.size())
		return true
	else:
		push_error("WebSocketStreamer not available")
		return false

func _notify_action_completed(action: String, success: bool = true):
	# Notify dashboard that action was completed
	var ws_streamer = get_node_or_null("/root/WebSocketStreamer")
	if ws_streamer and ws_streamer.has_method("_send_json"):
		ws_streamer._send_json({
			"type": "action_completed",
			"action": action,
			"success": success,
			"timestamp": Time.get_unix_time_from_system()
		})

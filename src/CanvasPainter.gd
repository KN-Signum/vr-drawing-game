# CanvasPainter.gd (Attach to the Painter2D node)
extends Node2D

var draw_points: Array = []
var draw_color: Color = Color.BLACK
var draw_width: float = 8.0

# Debug settings
@export var enable_debug: bool = true
@export var show_canvas_bounds: bool = true

# Function called by the Easel to add new points
func add_draw_point(point: Vector2, is_new_stroke: bool):
	if is_new_stroke:
		# Separate the strokes by adding a null entry
		draw_points.append(null) 
	
	# Debug: Print where we're drawing on the 2D canvas
	if enable_debug and point != Vector2.ZERO:
		var viewport = get_parent() as SubViewport
		var canvas_size = viewport.size if viewport else Vector2(1024, 1024)
		print("--- 2D CANVAS DEBUG ---")
		print("Drawing point at: ", point)
		print("Canvas size: ", canvas_size)
		print("Point normalized: (%.3f, %.3f)" % [point.x / canvas_size.x, point.y / canvas_size.y])
		print("Point in bounds: ", (point.x >= 0 and point.x <= canvas_size.x and point.y >= 0 and point.y <= canvas_size.y))
		print("----------------------")
	
	draw_points.append(point)
	
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
	
	for point in draw_points:
		if point == null:
			# Start of a new stroke
			last_point = Vector2.INF
			continue
		
		if last_point == Vector2.INF:
			# Initialize the stroke
			last_point = point
			# Draw a circle at the start of each stroke for debugging
			if enable_debug:
				draw_circle(point, 3.0, Color.BLUE)
		else:
			# draw_line is available on Node2D.
			draw_line(last_point, point, draw_color, draw_width) # <- Error Fixed
			last_point = point

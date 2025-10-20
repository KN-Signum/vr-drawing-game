# CanvasPainter.gd (Attach to the Painter2D node)
extends Node2D

var draw_points: Array = []
var draw_color: Color = Color.BLACK
var draw_width: float = 8.0

# Function called by the Easel to add new points
func add_draw_point(point: Vector2, is_new_stroke: bool):
	if is_new_stroke:
		# Separate the strokes by adding a null entry
		draw_points.append(null) 
	
	draw_points.append(point)
	
	# Request a redraw to update the texture. Node2D inherits CanvasItem.
	queue_redraw() # <- Error Fixed

func _draw():
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
		else:
			# draw_line is available on Node2D.
			draw_line(last_point, point, draw_color, draw_width) # <- Error Fixed
			last_point = point

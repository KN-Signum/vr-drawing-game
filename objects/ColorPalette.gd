# ColorPalette.gd
extends Node3D

# Store color data for each swatch
var color_map = {
	"RedSwatch": Color(1, 0, 0, 1),
	"BlueSwatch": Color(0, 0, 1, 1),
	"GreenSwatch": Color(0, 0.8, 0, 1),
	"YellowSwatch": Color(1, 1, 0, 1),
	"BlackSwatch": Color(0, 0, 0, 1),
	"WhiteSwatch": Color(1, 1, 1, 1)
}

func get_color_from_body(body: StaticBody3D) -> Color:
	if body and body.is_in_group("color_swatch"):
		var swatch_name = body.name
		if color_map.has(swatch_name):
			return color_map[swatch_name]
	return Color.BLACK  # Default color

extends Control

var accent := Color("ff6b08")
var bright := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e85b06") if bright else Color("0d1113")
	style.border_color = accent
	style.set_border_width_all(5)
	style.set_corner_radius_all(12)
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	# Fine diamond mesh and worn orange edging, drawn at display resolution.
	var mesh := Color(0.02, 0.025, 0.03, 0.19) if bright else Color(0.3, 0.34, 0.36, 0.12)
	for y in range(12, int(size.y) - 10, 8):
		for x in range(12, int(size.x) - 10, 8):
			draw_polyline(PackedVector2Array([Vector2(x, y - 3), Vector2(x + 3, y), Vector2(x, y + 3), Vector2(x - 3, y), Vector2(x, y - 3)]), mesh, 1)
	for x in range(24, int(size.x) - 18, 41):
		draw_line(Vector2(x, 2), Vector2(x + 7, 6), Color("80320a"), 2)
		draw_line(Vector2(x + 3, size.y - 2), Vector2(x + 10, size.y - 6), Color("371d11"), 2)
	draw_rect(Rect2(Vector2(7, 7), size - Vector2(14, 14)), Color("050607"), false, 3)
	for point in [Vector2(12, 12), Vector2(size.x - 12, 12), Vector2(12, size.y - 12), size - Vector2(12, 12)]:
		draw_circle(point, 7, Color("020508"))
		draw_circle(point, 5, Color("707e8b"))
		draw_circle(point + Vector2(-1, -2), 3, Color("c6d4de"))

extends Control

const ART := preload("res://scripts/reference_art.gd")
var bright := false
var outer := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

static func paint_patch(canvas: CanvasItem, offset: Vector2, target: Rect2, source: Rect2, tint: Color) -> void:
	canvas.draw_texture_rect_region(ART.SOURCE, Rect2(target.position + offset, target.size), source, tint)

func _draw() -> void:
	draw_at(self, Rect2(Vector2.ZERO, size), bright, outer)

static func draw_at(canvas: CanvasItem, rect: Rect2, bright: bool = false, outer: bool = false, tint: Color = Color.WHITE) -> void:
	var size := rect.size
	# Tile untouched paint or mesh from blank areas of the supplied reference.
	var fill := Rect2(178, 615, 38, 40) if bright else Rect2(320, 385, 128, 16)
	var step := Vector2i(fill.size * 0.5)
	for y in range(6, int(size.y - 6), step.y):
		for x in range(6, int(size.x - 6), step.x):
			var tile_size := Vector2(minf(step.x, size.x - 6 - x), minf(step.y, size.y - 6 - y))
			paint_patch(canvas, rect.position, Rect2(Vector2(x, y), tile_size), Rect2(fill.position, tile_size * 2), tint)
	var source := Rect2(646, 446, 232, 97) if bright else Rect2(65, 446, 564, 98)
	var corner := 40.0
	var edge := 12.0
	if outer:
		source = Rect2(26, 76, 889, 1506)
		corner = 30.0
		edge = 24.0
	var scale_factor := minf(0.58, size.y / (corner * 2))
	var cap := corner * scale_factor
	var stroke := edge * scale_factor
	# Corner bolts retain their proportions; only narrow, text-free edge strips stretch.
	for bottom in [false, true]:
		for right in [false, true]:
			var origin := Vector2(source.end.x - corner if right else source.position.x, source.end.y - corner if bottom else source.position.y)
			var target := Vector2(size.x - cap if right else 0.0, size.y - cap if bottom else 0.0)
			paint_patch(canvas, rect.position, Rect2(target, Vector2(cap, cap)), Rect2(origin, Vector2(corner, corner)), tint)
	paint_patch(canvas, rect.position, Rect2(cap, 0, size.x - cap * 2, stroke), Rect2(source.position.x + corner, source.position.y, source.size.x - corner * 2, edge), tint)
	paint_patch(canvas, rect.position, Rect2(cap, size.y - stroke, size.x - cap * 2, stroke), Rect2(source.position.x + corner, source.end.y - edge, source.size.x - corner * 2, edge), tint)
	paint_patch(canvas, rect.position, Rect2(0, cap, stroke, size.y - cap * 2), Rect2(source.position.x, source.position.y + corner, edge, source.size.y - corner * 2), tint)
	paint_patch(canvas, rect.position, Rect2(size.x - stroke, cap, stroke, size.y - cap * 2), Rect2(source.end.x - edge, source.position.y + corner, edge, source.size.y - corner * 2), tint)

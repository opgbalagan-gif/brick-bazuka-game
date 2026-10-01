extends RefCounted

const BILL := preload("res://assets/effects/banknote.svg")
const MAX_BILLS := 216
var bills: Array = []
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func clear() -> void:
	bills.clear()

func spawn(origin: Vector2, reduced: bool = false) -> void:
	var count := 24 if reduced else 72
	while bills.size() > MAX_BILLS - count:
		bills.pop_front()
	for index in count:
		var angle := rng.randf_range(-PI + 0.15, -0.15)
		var speed := rng.randf_range(170, 430)
		bills.append({
			"pos": origin + Vector2(rng.randf_range(-12, 12), rng.randf_range(-5, 5)),
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"rotation": rng.randf_range(-PI, PI), "spin": rng.randf_range(-7, 7),
			"phase": rng.randf_range(0, TAU), "width": rng.randf_range(22, 39),
			"age": 0.0, "life": rng.randf_range(1.5, 2.5)
		})

func update(delta: float) -> void:
	for bill in bills:
		bill["age"] += delta
		bill["vel"].y += 385.0 * delta
		bill["vel"].x *= exp(-0.55 * delta)
		bill["pos"] += bill["vel"] * delta
		bill["rotation"] += bill["spin"] * delta
	bills = bills.filter(func(bill): return bill["age"] < bill["life"])

func draw(canvas: CanvasItem) -> void:
	for bill in bills:
		var age: float = bill["age"]
		var alpha := clampf((float(bill["life"]) - age) / 0.55, 0, 1)
		var flutter := maxf(0.18, absf(cos(age * 9.0 + float(bill["phase"]))))
		var dimensions := Vector2(float(bill["width"]), float(bill["width"]) * 0.53)
		canvas.draw_set_transform(bill["pos"], bill["rotation"], Vector2(1, flutter))
		canvas.draw_texture_rect(BILL, Rect2(-dimensions * 0.5, dimensions), false, Color(1, 1, 1, alpha))
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

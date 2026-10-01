extends Control

const UI := preload("res://scripts/arcade_ui.gd")
const TOUCH := preload("res://scripts/touch_control.gd")
const HERO := preload("res://assets/characters/main_hero.png")
const ROCKET := preload("res://assets/weapons/rocket.svg")
var touch := TOUCH.new()
var keyboard_enabled := false
var hero_x := 220.0
var direction := 1.0
var elapsed := 0.0
var shots: Array = []
var shot_count := 0
var feedback := ""
var mouse_held := false

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(touch)
	touch.shot_requested.connect(shoot)
	visibility_changed.connect(reset)

func reset() -> void:
	touch.reset()
	mouse_held = false
	hero_x = size.x * 0.5
	shots.clear()
	shot_count = 0
	feedback = "СТРЕЛКИ / A D + ПРОБЕЛ" if keyboard_enabled else "ПОПРОБУЙ ДЕРЖАТЬ ПАЛЕЦ СЛЕВА ИЛИ СПРАВА"
	queue_redraw()

func shoot() -> void:
	shot_count += 1
	shots.append({"pos": Vector2(hero_x + direction * 40, hero_y() - 10), "direction": direction, "age": 0.0})
	feedback = "ЕСТЬ ВЫСТРЕЛ!  ×" + str(shot_count)

func hero_y() -> float:
	return 119.0 - absf(sin(elapsed * 3.0)) * 36.0

func mapped_position(point: Vector2) -> Vector2:
	return Vector2(point.x * 540.0 / size.x, point.y)

func pass_touch(event: InputEvent, local_position: Vector2) -> void:
	var copy := event.duplicate()
	copy.position = mapped_position(local_position)
	touch.handle_event(copy)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if keyboard_enabled:
			shoot()
		else:
			pass_touch(event, event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if keyboard_enabled:
			shoot()
		else:
			mouse_held = true
			var press := InputEventScreenTouch.new()
			press.index = 10000
			press.pressed = true
			pass_touch(press, event.position)
		accept_event()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# Track an active gesture outside the practice box too, so releasing never sticks.
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and touch.touches.has(event.index):
		pass_touch(event, get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
	elif mouse_held and (event is InputEventMouseMotion or event is InputEventMouseButton):
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event is InputEventMouseMotion:
			var drag := InputEventScreenDrag.new()
			drag.index = 10000
			pass_touch(drag, point)
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			mouse_held = false
			var release := InputEventScreenTouch.new()
			release.index = 10000
			pass_touch(release, point)
		get_viewport().set_input_as_handled()
	elif keyboard_enabled and event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode else event.keycode
		if key == KEY_SPACE:
			shoot()
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		touch.reset()
		mouse_held = false

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	elapsed += delta
	touch.advance(delta)
	var axis: float = touch.axis
	if keyboard_enabled:
		var right := Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)
		var left := Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)
		axis = float(right) - float(left)
	if absf(axis) > 0.02:
		direction = signf(axis)
		feedback = "ДВИЖЕНИЕ ВПРАВО" if axis > 0 else "ДВИЖЕНИЕ ВЛЕВО"
	hero_x = clampf(hero_x + axis * 220 * delta, 50, size.x - 50)
	for shot in shots:
		shot["pos"].x += shot["direction"] * 430 * delta
		shot["age"] += delta
	shots = shots.filter(func(shot): return shot["age"] < 1.2)
	queue_redraw()

func _draw() -> void:
	UI.METAL.draw_at(self, Rect2(Vector2.ZERO, size))
	if not keyboard_enabled:
		draw_rect(Rect2(14, 14, size.x * 0.5 - 14, size.y - 47), Color(0.72, 0.95, 0.05, 0.045))
		draw_line(Vector2(size.x * 0.5, 18), Vector2(size.x * 0.5, size.y - 42), Color(1, 1, 1, 0.14), 2)
	var arrow := PackedVector2Array([Vector2(0, 12), Vector2(12, 0), Vector2(12, 8), Vector2(30, 8), Vector2(30, 16), Vector2(12, 16), Vector2(12, 24)])
	draw_set_transform(Vector2(26, 26))
	draw_colored_polygon(arrow, UI.ORANGE)
	draw_set_transform(Vector2(size.x - 26, 26), 0, Vector2(-1, 1))
	draw_colored_polygon(arrow, UI.ORANGE)
	draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(22, 161), Vector2(size.x - 22, 161), Color("555943"), 4)
	draw_set_transform(Vector2(hero_x, hero_y()), 0, Vector2(-direction, 1))
	draw_texture_rect(HERO, Rect2(-54, -46, 108, 92), false)
	draw_set_transform(Vector2.ZERO)
	for shot in shots:
		draw_set_transform(shot["pos"], PI * 0.5 * shot["direction"])
		draw_texture_rect(ROCKET, Rect2(-8, -14, 16, 28), false)
	draw_set_transform(Vector2.ZERO)
	var width := UI.FONT.get_string_size(feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	caption(feedback, Vector2((size.x - width) * 0.5, size.y - 17), 16, UI.LIME)

func caption(value: String, point: Vector2, font_size: int, color: Color) -> void:
	draw_string_outline(UI.FONT, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
	draw_string(UI.FONT, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

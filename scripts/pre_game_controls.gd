extends Control

signal play_requested
signal back_requested
const GLOVE := preload("res://assets/ui/tap_glove.svg")
const UI := preload("res://scripts/arcade_ui.gd")
var tilt_control
var swipe_button: Button
var tilt_button: Button
var play_button: Button
var back_button: Button
var instructions: Label
var icons: Control
var elapsed := 0.0

func _ready() -> void:
	size = Vector2(540, 960)
	z_index = 26
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.size = size
	dim.color = Color(0.015, 0.02, 0.025, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	UI.panel(self, Rect2(28, 174, 484, 82), true)
	text("КАК БУДЕМ ИГРАТЬ?", Rect2(40, 194, 460, 42), 32)
	text("ВЫБЕРИ УПРАВЛЕНИЕ", Rect2(40, 277, 460, 30), 23, UI.LIME)
	swipe_button = action("", Rect2(32, 328, 230, 225), func(): select_mode("touch"))
	tilt_button = action("", Rect2(278, 328, 230, 225), func(): select_mode("tilt"))
	icons = Control.new()
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icons.draw.connect(draw_icons)
	add_child(icons)
	text("СВАЙП", Rect2(44, 502, 206, 34), 26)
	text("НАКЛОН", Rect2(290, 502, 206, 34), 26)
	instructions = text("", Rect2(30, 580, 480, 78), 23)
	text("ТАП — ВЫСТРЕЛ\nПРЫЖКИ И ПРИЦЕЛ — АВТОМАТИЧЕСКИ", Rect2(30, 669, 480, 56), 19, UI.LIME)
	play_button = action("ИГРАТЬ", Rect2(94, 753, 352, 74), func(): play_requested.emit())
	play_button.add_theme_font_size_override("font_size", 32)
	back_button = action("НАЗАД", Rect2(180, 850, 180, 50), func(): back_requested.emit())
	text("НА КОМПЬЮТЕРЕ: A / D ИЛИ СТРЕЛКИ\nПРОБЕЛ — ВЫСТРЕЛ", Rect2(25, 101, 490, 46), 17)
	hide()

func text(value: String, rect: Rect2, font_size: int, color: Color = UI.WHITE) -> Label:
	var label := UI.label(value, font_size, color)
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func action(value: String, rect: Rect2, callback: Callable) -> Button:
	var button := UI.button(value, true)
	button.position = rect.position
	button.size = rect.size
	button.pressed.connect(callback)
	add_child(button)
	return button

func open() -> void:
	elapsed = 0.0
	show()
	select_mode(tilt_control.mode)

func select_mode(mode: String) -> void:
	# Permission is requested only when the player confirms the new run.
	tilt_control.stop()
	tilt_control.set_mode(mode)
	instructions.text = "ВЕДИ ПАЛЬЦЕМ ВЛЕВО / ВПРАВО\nУДЕРЖИВАЙ, ЧТОБЫ ДВИГАТЬСЯ" if mode == "touch" else "ДЕРЖИ ТЕЛЕФОН УДОБНО\nНАКЛОНЯЙ ВЛЕВО / ВПРАВО"
	swipe_button.modulate = Color.WHITE if mode == "touch" else Color("858585")
	tilt_button.modulate = Color.WHITE if mode == "tilt" else Color("858585")
	icons.queue_redraw()

func _process(delta: float) -> void:
	if visible:
		elapsed += delta
		icons.queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back_requested.emit()
	elif event.keycode == KEY_ENTER and not get_viewport().gui_get_focus_owner():
		get_viewport().set_input_as_handled()
		play_requested.emit()

func draw_icons() -> void:
	var motion := sin(elapsed * 2.2)
	for center_x in [147, 393]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("111c22")
		box.border_color = Color("050709")
		box.set_border_width_all(3)
		box.set_corner_radius_all(14)
		icons.draw_style_box(box, Rect2(center_x - 98, 356, 196, 137))
	# Glove follows an eased swipe, with a fading lime trail and contact pulse.
	for step in range(14, 0, -1):
		var previous := sin((elapsed - step * 0.035) * 2.2)
		icons.draw_circle(Vector2(147 + previous * 51, 398), 3 + (14 - step) * 0.3, Color(0.72, 0.95, 0.1, (1.0 - step / 15.0) * 0.55))
	var finger := Vector2(147 + motion * 51, 398)
	var pulse := fmod(elapsed * 1.1, 1.0)
	icons.draw_arc(finger, 9 + pulse * 19, 0, TAU, 32, Color(0.72, 0.95, 0.1, 1.0 - pulse), 2, true)
	icons.draw_set_transform(finger, -motion * 0.12)
	icons.draw_rect(Rect2(-16, 62, 41, 28), Color("06090d"))
	icons.draw_texture_rect(GLOVE, Rect2(-34, -6, 90, 99), false)
	icons.draw_set_transform(Vector2.ZERO)
	# Both gloves, cuffs and phone rotate together, as if held by the hero.
	icons.draw_set_transform(Vector2(393, 425 + cos(elapsed * 2.2) * 3), motion * 0.24)
	for side in [-1, 1]:
		icons.draw_set_transform(Vector2(393, 425 + cos(elapsed * 2.2) * 3), motion * 0.24, Vector2(side, 1))
		icons.draw_rect(Rect2(37, 42, 30, 20), Color("05080d"))
		icons.draw_texture_rect(GLOVE, Rect2(18, -6, 62, 68), false)
	icons.draw_set_transform(Vector2(393, 425 + cos(elapsed * 2.2) * 3), motion * 0.24)
	icons.draw_rect(Rect2(-32, -57, 64, 113), Color("06090d"))
	icons.draw_rect(Rect2(-30, -55, 60, 109), UI.WHITE, false, 3)
	icons.draw_rect(Rect2(-24, -41, 48, 76), Color("24353c"))
	icons.draw_line(Vector2(-9, -48), Vector2(9, -48), UI.ORANGE, 3)
	icons.draw_circle(Vector2(0, 45), 4, UI.LIME)
	# The little player slides with the tilt, showing what the gesture does.
	icons.draw_line(Vector2(-21, 24), Vector2(21, 24), UI.WHITE, 3)
	icons.draw_circle(Vector2(motion * 13, 12), 7, UI.LIME)
	icons.draw_circle(Vector2(motion * 13 - 2, 11), 1.5, Color.BLACK)
	icons.draw_circle(Vector2(motion * 13 + 2, 11), 1.5, Color.BLACK)
	for side in [-1, 1]:
		icons.draw_arc(Vector2(side * 64, -22), 10 + absf(motion) * 6, -1.0 if side == 1 else PI - 1.0, 1.0 if side == 1 else PI + 1.0, 12, Color(0.72, 0.95, 0.1, absf(motion)), 3, true)
	icons.draw_set_transform(Vector2.ZERO)
	var center := Vector2(147 if tilt_control.mode == "touch" else 393, 347)
	icons.draw_circle(center, 5, UI.LIME)

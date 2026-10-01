extends Control

signal resume_requested
signal settings_requested
signal restart_requested
signal home_requested

const UI := preload("res://scripts/arcade_ui.gd")
var resume_button: Button
var settings_button: Button
var restart_button: Button
var home_button: Button
var score_label: Label

func _ready() -> void:
	size = Vector2(540, 960)
	z_index = 24
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.size = size
	dim.color = Color(0, 0, 0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var frame := UI.panel(self, Rect2(38, 224, 464, 502))
	frame.outer = true
	UI.panel(self, Rect2(54, 240, 432, 80), true)
	var title := UI.label("ПАУЗА", 44)
	title.position = Vector2(70, 251)
	title.size = Vector2(400, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	score_label = UI.label("", 23, UI.LIME)
	score_label.position = Vector2(64, 337)
	score_label.size = Vector2(412, 32)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(score_label)
	resume_button = UI.button("ПРОДОЛЖИТЬ", true)
	resume_button.add_theme_font_size_override("font_size", 30)
	place(resume_button, Rect2(64, 388, 412, 76), func(): resume_requested.emit())
	settings_button = UI.button("НАСТРОЙКИ И УПРАВЛЕНИЕ", true)
	settings_button.add_theme_font_size_override("font_size", 23)
	place(settings_button, Rect2(64, 481, 412, 66), func(): settings_requested.emit())
	restart_button = UI.art_button("again", "ЕЩЁ РАЗ")
	place(restart_button, Rect2(64, 568, 198, 70), func(): restart_requested.emit())
	home_button = UI.art_button("menu", "МЕНЮ")
	place(home_button, Rect2(280, 568, 196, 70), func(): home_requested.emit())
	var hint := UI.label("ЗАБЕГ ЖДЁТ ТЕБЯ", 18)
	hint.position = Vector2(64, 665)
	hint.size = Vector2(412, 28)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	hide()

func place(button: Button, rect: Rect2, callback: Callable) -> void:
	button.position = rect.position
	button.size = rect.size
	button.pressed.connect(callback)
	add_child(button)

func open(score: int) -> void:
	score_label.text = str(score) + " ОЧКОВ"
	show()

static func make_pause_button() -> Button:
	var button := UI.button("", true)
	button.tooltip_text = "Пауза"
	button.size = Vector2(60, 64)
	button.focus_mode = Control.FOCUS_NONE
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func():
		for x in [19, 33]:
			icon.draw_rect(Rect2(x - 2, 18, 12, 28), Color.BLACK)
			icon.draw_rect(Rect2(x, 20, 8, 24), UI.WHITE))
	button.add_child(icon)
	return button

extends Control

signal closed
signal changed(sensitivity: float, reduced_effects: bool)

const UI := preload("res://scripts/arcade_ui.gd")
const PRACTICE := preload("res://scripts/control_practice.gd")
const SENSITIVITIES := [0.7, 1.0, 1.4]
var sensitivity := 1.0
var reduced_effects := false
var phone_button: Button
var desktop_button: Button
var sensitivity_buttons: Array[Button] = []
var effect_button: Button
var instructions: Label
var practice
var close_button: Button

func _ready() -> void:
	size = Vector2(540, 960)
	z_index = 30
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.size = size
	dim.color = Color(0, 0, 0, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var frame := UI.panel(self, Rect2(18, 18, 504, 924))
	frame.outer = true
	UI.panel(self, Rect2(32, 34, 476, 76), true)
	text("НАСТРОЙКИ И УПРАВЛЕНИЕ", Rect2(42, 49, 456, 44), 28, UI.WHITE, true)
	phone_button = action("ТЕЛЕФОН", Rect2(38, 126, 224, 52), func(): select_device(false))
	desktop_button = action("КОМПЬЮТЕР", Rect2(278, 126, 224, 52), func(): select_device(true))
	instructions = text("", Rect2(46, 196, 448, 144), 20)
	instructions.add_theme_constant_override("line_spacing", 6)
	text("ПРЫЖКИ И ПРИЦЕЛ — АВТОМАТИЧЕСКИ", Rect2(40, 351, 460, 25), 18, UI.LIME, true)
	text("ПОПРОБУЙ ЗДЕСЬ", Rect2(40, 393, 460, 27), 23, UI.ORANGE, true)
	practice = PRACTICE.new()
	practice.position = Vector2(40, 434)
	practice.size = Vector2(460, 211)
	add_child(practice)
	text("ЧУВСТВИТЕЛЬНОСТЬ СВАЙПА", Rect2(40, 665, 460, 25), 20, UI.WHITE, true)
	var labels := ["ПЛАВНО", "ОБЫЧНО", "БЫСТРО"]
	for index in 3:
		var button := action(labels[index], Rect2(40 + 157 * index, 704, 146, 50), func():
			sensitivity = SENSITIVITIES[index]
			refresh()
			changed.emit(sensitivity, reduced_effects))
		sensitivity_buttons.append(button)
	effect_button = action("", Rect2(40, 775, 460, 50), func():
		reduced_effects = not reduced_effects
		refresh()
		changed.emit(sensitivity, reduced_effects))
	text("Спокойные: без вспышек и тряски, меньше купюр.", Rect2(40, 829, 460, 20), 15, UI.LIME, true)
	close_button = action("ГОТОВО", Rect2(110, 857, 320, 60), close)
	select_device(false)
	hide()

func text(value: String, rect: Rect2, font_size: int, color: Color = UI.WHITE, centered: bool = false) -> Label:
	var label := UI.label(value, font_size, color)
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	return label

func action(value: String, rect: Rect2, callback: Callable) -> Button:
	var button := UI.button(value, true)
	button.position = rect.position
	button.size = rect.size
	button.pressed.connect(callback)
	add_child(button)
	return button

func select_device(desktop: bool) -> void:
	practice.keyboard_enabled = desktop
	practice.reset()
	phone_button.modulate = Color("8f969d") if desktop else Color.WHITE
	desktop_button.modulate = Color.WHITE if desktop else Color("8f969d")
	instructions.text = "СТРЕЛКИ / A D (Ф В) — двигайся.\nПРОБЕЛ или клик — стреляй.\nESC — пауза во время игры.\nВ поле ниже проверь движение и выстрел." if desktop else "Держи слева / справа — двигайся.\nИли веди палец в нужную сторону.\nОтпусти — остановись. Короткий тап — выстрел.\nВторым пальцем можно стрелять на ходу.\nДве полоски сверху — пауза и настройки."
	refresh()

func refresh() -> void:
	if not is_instance_valid(practice):
		return
	practice.touch.sensitivity = sensitivity
	for index in sensitivity_buttons.size():
		var selected := is_equal_approx(sensitivity, SENSITIVITIES[index])
		sensitivity_buttons[index].modulate = Color.WHITE if selected else Color("858d91")
		var caption: String = ["ПЛАВНО", "ОБЫЧНО", "БЫСТРО"][index]
		sensitivity_buttons[index].text = "[ " + caption + " ]" if selected else caption
	effect_button.text = "ЭФФЕКТЫ: СПОКОЙНЫЕ" if reduced_effects else "ЭФФЕКТЫ: ПОЛНЫЕ"
	effect_button.tooltip_text = "Спокойные: меньше купюр, без вспышек и тряски экрана."

func open(current_sensitivity: float, current_reduced_effects: bool) -> void:
	sensitivity = current_sensitivity
	reduced_effects = current_reduced_effects
	refresh()
	show()
	practice.reset()

func close() -> void:
	hide()
	practice.reset()
	closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

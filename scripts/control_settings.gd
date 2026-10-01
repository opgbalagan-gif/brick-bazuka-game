extends Control

signal closed
signal changed(sensitivity: float, reduced_effects: bool)

const UI := preload("res://scripts/arcade_ui.gd")
const PRACTICE := preload("res://scripts/control_practice.gd")
const SENSITIVITIES := [0.7, 1.0, 1.4]
var sensitivity := 1.0
var reduced_effects := false
var phone_button: Button
var tilt_button: Button
var desktop_button: Button
var tilt_control
var calibration_button: Button
var sensor_status: Label
var sensitivity_label: Label
var practice_title: Label
var last_status := ""
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
	phone_button = action("ПАЛЬЦЕМ", Rect2(38, 126, 144, 52), func(): select_device(false))
	tilt_button = action("НАКЛОНОМ", Rect2(198, 126, 144, 52), func(): select_device(false, true))
	desktop_button = action("КЛАВИШИ", Rect2(358, 126, 144, 52), func(): select_device(true))
	instructions = text("", Rect2(46, 196, 448, 144), 20)
	instructions.add_theme_constant_override("line_spacing", 6)
	sensor_status = text("", Rect2(40, 319, 460, 24), 16, UI.LIME, true)
	text("ПРЫЖКИ И ПРИЦЕЛ — АВТОМАТИЧЕСКИ", Rect2(40, 351, 460, 25), 18, UI.LIME, true)
	practice_title = text("ПОПРОБУЙ ЗДЕСЬ", Rect2(40, 393, 460, 27), 23, UI.ORANGE, true)
	calibration_button = action("ЦЕНТР", Rect2(334, 386, 166, 42), func():
		if is_instance_valid(tilt_control):
			tilt_control.calibrate()
			practice.reset()
			refresh())
	calibration_button.custom_minimum_size.y = 42
	practice = PRACTICE.new()
	practice.tilt_control = tilt_control
	practice.position = Vector2(40, 434)
	practice.size = Vector2(460, 211)
	add_child(practice)
	sensitivity_label = text("ЧУВСТВИТЕЛЬНОСТЬ СВАЙПА", Rect2(40, 665, 460, 25), 20, UI.WHITE, true)
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
	hide()
	select_device(false, is_instance_valid(tilt_control) and tilt_control.mode == "tilt")

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

func select_device(desktop: bool, sensor: bool = false) -> void:
	practice.keyboard_enabled = desktop
	if is_instance_valid(tilt_control):
		tilt_control.set_mode("tilt" if sensor else "touch")
		if sensor and visible:
			tilt_control.start()
		else:
			tilt_control.stop()
	practice.tilt_enabled = sensor
	practice.reset()
	refresh()

func refresh() -> void:
	if not is_instance_valid(practice):
		return
	var sensor: bool = is_instance_valid(tilt_control) and tilt_control.mode == "tilt" and not practice.keyboard_enabled
	if practice.tilt_enabled != sensor:
		practice.tilt_enabled = sensor
		practice.reset()
	phone_button.modulate = Color.WHITE if not practice.keyboard_enabled and not sensor else Color("858d91")
	tilt_button.modulate = Color.WHITE if sensor else Color("858d91")
	desktop_button.modulate = Color.WHITE if practice.keyboard_enabled else Color("858d91")
	instructions.text = "СТРЕЛКИ / A D (Ф В) — двигайся.\nПРОБЕЛ или клик — стреляй.\nESC — пауза во время игры.\nВ поле ниже проверь движение и выстрел." if practice.keyboard_enabled else "Держи слева / справа — двигайся.\nИли веди палец в нужную сторону.\nОтпусти — остановись. Короткий тап — выстрел.\nВторым пальцем можно стрелять на ходу.\nДве полоски сверху — пауза и настройки."
	if sensor:
		instructions.text = "Наклоняй телефон влево или вправо.\nБольше наклон — быстрее движение.\nКороткий тап — выстрел.\nДержи удобно и нажми «ЦЕНТР»."
	last_status = tilt_control.get_status() if sensor else ""
	var messages := {
		"active": "НАКЛОН ВКЛЮЧЁН — МОЖНО ПРОБОВАТЬ",
		"waiting": "Держи телефон удобно — ждём датчик…",
		"permission": "Разреши наклон в открывшемся окне.",
		"requesting": "Ожидаем разрешение на наклон…",
		"denied": "Нет доступа к датчику. Выбери «ПАЛЬЦЕМ».",
		"unavailable": "Датчик недоступен. Выбери «ПАЛЬЦЕМ».",
		"insecure": "Для наклона открой игру по HTTPS."
	}
	sensor_status.text = messages.get(last_status, "")
	calibration_button.visible = sensor
	calibration_button.disabled = last_status not in ["active", "waiting"]
	practice_title.size.x = 280 if sensor else 460
	sensitivity_label.text = "ЧУВСТВИТЕЛЬНОСТЬ НАКЛОНА" if sensor else "ЧУВСТВИТЕЛЬНОСТЬ СВАЙПА"
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
	select_device(false, is_instance_valid(tilt_control) and tilt_control.mode == "tilt")

func close() -> void:
	hide()
	practice.reset()
	closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if visible and is_instance_valid(tilt_control):
		var current: String = tilt_control.get_status() if practice.tilt_enabled else ""
		if current != last_status or practice.tilt_enabled != (tilt_control.mode == "tilt" and not practice.keyboard_enabled):
			refresh()

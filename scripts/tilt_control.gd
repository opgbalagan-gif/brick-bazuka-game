extends Node

signal mode_changed(value: String)

var web_input: JavaScriptObject
var native_neutral := 0.0
var native_calibrated := false
var mode := "touch"
var sensitivity := 1.0
var active := false


func _ready() -> void:
	if OS.has_feature("web"):
		web_input = JavaScriptBridge.get_interface("BrickTilt")
		if web_input != null:
			web_input.set_mode(mode)
			web_input.set_sensitivity(sensitivity)


func _process(_delta: float) -> void:
	# The permission dialog can also switch back to finger controls.
	if web_input != null:
		var current := str(web_input.get_mode())
		if current != mode:
			mode = current
			mode_changed.emit(mode)


func set_mode(value: String) -> void:
	var next := "tilt" if value == "tilt" else "touch"
	var changed := next != mode
	mode = next
	if changed:
		native_calibrated = false
	if web_input != null:
		web_input.set_mode(mode)
	if changed:
		mode_changed.emit(mode)


func set_sensitivity(value: float) -> void:
	sensitivity = clampf(value, 0.7, 1.4)
	if web_input != null:
		web_input.set_sensitivity(sensitivity)


func calibrate() -> void:
	native_calibrated = false
	if web_input != null:
		web_input.calibrate()


func get_status() -> String:
	if mode != "tilt":
		return "buttons"
	if web_input != null:
		return str(web_input.get_status())
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return "unavailable"
	return "active" if native_calibrated else "waiting"


func start() -> void:
	active = true
	if web_input != null:
		web_input.start()


func stop() -> void:
	active = false
	if web_input != null:
		web_input.stop()


func needs_permission() -> bool:
	return web_input != null and bool(web_input.needs_permission())


func uses_keyboard() -> bool:
	# The published browser game introduces phone controls on every device.
	if OS.has_feature("web"):
		return false
	return not (OS.has_feature("android") or OS.has_feature("ios"))


func read_axis() -> float:
	var right := Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)
	var left := Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)
	if right or left:
		return float(right) - float(left)
	return read_sensor_axis()


func read_sensor_axis() -> float:
	if not active or mode != "tilt":
		return 0.0
	if web_input != null:
		return clampf(float(web_input.read_axis()), -1.0, 1.0)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var gravity := Input.get_gravity()
		if gravity.length() < 1.0:
			gravity = Input.get_accelerometer()
		if gravity.length() < 1.0:
			return 0.0
		var roll := rad_to_deg(asin(clampf(gravity.normalized().x, -1.0, 1.0)))
		if not native_calibrated:
			native_neutral = roll
			native_calibrated = true
		var relative := roll - native_neutral
		return signf(relative) * clampf((absf(relative) - 3.0) * sensitivity / 19.0, 0.0, 1.0)
	return 0.0

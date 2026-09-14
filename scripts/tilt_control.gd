extends Node

var web_input: JavaScriptObject
var native_neutral := 0.0
var native_calibrated := false


func _ready() -> void:
	if OS.has_feature("web"):
		web_input = JavaScriptBridge.get_interface("BrickTilt")


func start() -> void:
	native_calibrated = false
	if web_input != null:
		web_input.start()


func stop() -> void:
	if web_input != null:
		web_input.stop()


func needs_permission() -> bool:
	return web_input != null and bool(web_input.needs_permission())


func read_axis() -> float:
	var keyboard := float(Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A))
	if not is_zero_approx(keyboard):
		return keyboard
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
		return signf(relative) * clampf((absf(relative) - 3.0) / 19.0, 0.0, 1.0)
	return 0.0

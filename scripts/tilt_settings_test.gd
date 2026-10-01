extends SceneTree

class Sensor extends RefCounted:
	var axis := 0.0
	func read_sensor_axis() -> float:
		return axis

func _init() -> void:
	run.call_deferred()

func tap(control: Control) -> void:
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = control.get_global_rect().get_center()
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func run() -> void:
	var path := "user://tilt_settings_test.cfg"
	DirAccess.remove_absolute(path)
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = path
	root.add_child(game)
	game.leaderboard.api_url = ""
	game.set_process(false)
	assert(game.control_mode == "touch" and not game.tilt_control.active, "Menu must not activate sensors by default")
	game.open_control_settings()
	var settings = game.control_settings
	await tap(settings.tilt_button)
	assert(game.control_mode == "tilt" and game.tilt_control.mode == "tilt" and game.tilt_control.active, "A real settings tap must select and start tilt")
	assert(settings.practice.tilt_enabled and settings.calibration_button.visible and "НАКЛОНА" in settings.sensitivity_label.text)
	await tap(settings.sensitivity_buttons[2])
	assert(is_equal_approx(game.tilt_control.sensitivity, 1.4), "Sensitivity buttons must reach the sensor controller")
	var sensor := Sensor.new()
	settings.practice.tilt_control = sensor
	settings.practice.set_process(false)
	var before: float = settings.practice.hero_x
	sensor.axis = 1.0
	settings.practice._process(0.1)
	assert(settings.practice.hero_x > before, "Training must display live tilt input")
	sensor.axis = -1.0
	settings.practice._process(0.2)
	assert(settings.practice.hero_x < before)
	settings.practice.tilt_control = game.tilt_control
	await tap(settings.phone_button)
	assert(game.control_mode == "touch" and not game.tilt_control.active and not settings.calibration_button.visible, "Finger mode must stop the sensor and hide calibration")
	await tap(settings.tilt_button)
	settings.close()
	assert(not game.tilt_control.active, "Closing menu settings must stop sensor listening")
	game.start_game()
	assert(game.tilt_control.active and game.control_mode == "tilt", "The selected mode must be used by the next run")
	game.open_pause()
	assert(not game.tilt_control.active)
	game.open_control_settings()
	assert(settings.practice.tilt_enabled and game.tilt_control.active, "Pause settings must preview the selected sensor mode")
	settings.close()
	assert(game.paused and not game.tilt_control.active, "Returning to pause must stop preview sensors")
	game.resume_game()
	assert(not game.paused and game.tilt_control.active)
	game.return_to_menu()
	game.free()
	var restored = load("res://scenes/main.tscn").instantiate()
	restored.profile_path = path
	root.add_child(restored)
	restored.leaderboard.api_url = ""
	assert(restored.control_mode == "tilt" and restored.tilt_control.mode == "tilt" and not restored.tilt_control.active, "Mode must survive reload without starting sensors in the menu")
	assert(is_equal_approx(restored.tilt_control.sensitivity, 1.4))
	restored.free()
	DirAccess.remove_absolute(path)
	print("TILT_SETTINGS_TEST_OK touch_buttons persisted_mode sensitivity live_training preview_lifecycle pause_resume")
	quit()

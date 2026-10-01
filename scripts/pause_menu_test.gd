extends SceneTree

func _init() -> void:
	run.call_deferred()

func tap(control: Control, id: int = 3) -> void:
	var point := control.get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = point
		event.index = id
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func run() -> void:
	var path := "user://pause_menu_test.cfg"
	DirAccess.remove_absolute(path)
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = path
	root.add_child(game)
	game.leaderboard.api_url = ""
	game.set_process(false)
	game.start_game()
	game.height_meters = 3834
	game.hit_timer = 0.8
	game.reload_timer = 0.5
	game.cash_burst.spawn(Vector2(270, 500))
	await process_frame
	assert(game.pause_button.visible)
	var steering_touch := InputEventScreenTouch.new()
	steering_touch.index = 0
	steering_touch.position = Vector2(70, 640)
	steering_touch.pressed = true
	root.push_input(steering_touch, true)
	game.touch_control.advance(0.2)
	assert(game.touch_control.is_steering())
	await tap(game.pause_button)
	assert(game.paused and game.pause_menu.visible, "A phone tap on the top button must open pause")
	assert(game.touch_control.touches.is_empty() and game.rockets.is_empty(), "Pausing must not steer or fire")
	var position: Vector2 = game.player_pos
	var blocks: Array = game.blocks.duplicate(true)
	var bills: Array = game.cash_burst.bills.duplicate(true)
	game._process(2.0)
	assert(game.player_pos == position and game.blocks == blocks and game.cash_burst.bills == bills, "Pause must freeze the entire run")
	assert(is_equal_approx(game.hit_timer, 0.8) and is_equal_approx(game.reload_timer, 0.5), "Pause must preserve protection and reload timers")
	await tap(game.pause_menu.settings_button)
	assert(game.control_settings.visible and not game.pause_menu.visible and game.paused)
	await tap(game.control_settings.sensitivity_buttons[0])
	assert(is_equal_approx(game.touch_sensitivity, 0.7), "Settings must work on a touch screen from pause")
	await tap(game.control_settings.close_button)
	assert(game.pause_menu.visible and game.paused and not game.control_settings.visible, "Settings back must return to pause without resuming")
	await tap(game.pause_menu.resume_button)
	steering_touch.pressed = false
	root.push_input(steering_touch, true)
	assert(not game.paused and not game.pause_menu.visible and game.pause_button.visible)
	assert(game.player_pos == position and game.height_meters == 3834 and game.rockets.is_empty(), "Continue must preserve score and not fire on release")
	await click(game.pause_button)
	assert(game.paused and game.pause_menu.visible, "Mouse pause must also work")
	await click(game.pause_menu.settings_button)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	assert(game.paused and game.pause_menu.visible and not game.control_settings.visible, "Escape in settings must return to pause")
	escape.pressed = false
	root.push_input(escape, true)
	game.rewards.coins = 100
	await click(game.pause_menu.restart_button)
	assert(not game.paused and not game.pause_menu.visible and game.height_meters == 0 and game.health == 3, "Restart must start a fresh run")
	assert(game.rewards.coins == 100, "Restart must preserve collected currency")
	await click(game.pause_button)
	await tap(game.pause_menu.home_button)
	assert(game.screen == game.Screen.MENU and not game.paused and not game.pause_menu.visible and not game.pause_button.visible)
	assert(game.rewards.coins == 100, "Returning to menu must keep earned currency")
	game.start_game()
	game.finish_run()
	game.sync_pause_controls()
	assert(not game.pause_menu.visible and not game.pause_button.visible, "Pause controls must be hidden on game over")
	game.free()
	DirAccess.remove_absolute(path)
	print("PAUSE_MENU_TEST_OK touch mouse freeze settings_return resume_no_shot restart wallet menu gameover")
	quit()

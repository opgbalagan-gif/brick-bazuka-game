extends SceneTree

func _init() -> void:
	run.call_deferred()

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
	var path := "user://settings_effects_test.cfg"
	DirAccess.remove_absolute(path)
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = path
	root.add_child(game)
	game.leaderboard.api_url = ""
	game.set_process(false)
	await process_frame
	await click(game.settings_button)
	assert(game.control_settings.visible and game.screen == game.Screen.MENU, "Settings entry must open without starting a run")
	var settings = game.control_settings
	await click(settings.sensitivity_buttons[2])
	await click(settings.effect_button)
	assert(is_equal_approx(game.touch_control.sensitivity, 1.4) and game.reduced_effects, "Settings buttons must affect the actual game")
	var practice = settings.practice
	await click(practice)
	assert(practice.shot_count == 1 and game.rockets.is_empty(), "Practice tap must shoot in the demo only")
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = practice.global_position + Vector2(400, 100)
	press.index = 4
	root.push_input(press, true)
	practice.touch.advance(0.2)
	assert(practice.touch.axis > 0.9, "Practice must teach the same hold behavior as the game")
	var release := InputEventScreenTouch.new()
	release.index = 4
	release.position = Vector2(535, 950)
	root.push_input(release, true)
	assert(practice.touch.touches.is_empty(), "Releasing outside training must stop steering")
	await click(settings.desktop_button)
	assert(practice.keyboard_enabled)
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space, true)
	assert(practice.shot_count == 1 and game.screen == game.Screen.MENU, "Practice keyboard shot must not launch the real run")
	await click(settings.close_button)
	assert(not settings.visible and not game.paused)
	game.start_game()
	game.paused = true
	game.open_control_settings()
	settings.close()
	assert(game.paused, "Settings must preserve an existing pause")
	game.paused = false
	game.blocks = [{"pos": Vector2(220, 620), "size": Vector2(150, 50), "reward": "case"}]
	game.player_pos = Vector2(290, 584)
	game.previous_player_pos = game.player_pos
	game.reduced_effects = false
	var world_rng_state: int = game.rng.state
	game.check_reward_pickups()
	assert(game.cash_burst.bills.size() == 72 and game.rewards.coins == 100)
	assert(game.rng.state == world_rng_state, "Visual money must not alter procedural generation")
	game.check_reward_pickups()
	assert(game.cash_burst.bills.size() == 72 and game.rewards.coins == 100, "Cash burst and credit must happen only once")
	game.blocks[0]["reward"] = "safe"
	game.check_reward_pickups()
	assert(game.cash_burst.bills.size() == 72 and game.rewards.promo_tickets == 1, "Promo safe must not emit cash")
	for index in 10:
		game.cash_burst.spawn(Vector2(250, 500))
	assert(game.cash_burst.bills.size() <= game.cash_burst.MAX_BILLS, "Rapid pickup effects must remain bounded")
	for index in 180:
		game.cash_burst.update(1.0 / 60.0)
	assert(game.cash_burst.bills.is_empty(), "Bills must expire instead of accumulating")
	game.cash_burst.spawn(Vector2.ZERO, true)
	assert(game.cash_burst.bills.size() == 24, "Calm mode must reduce bill count")
	game.reduced_effects = true
	game.save_profile()
	game.start_game()
	assert(game.cash_burst.bills.is_empty(), "Restart must clear previous-run money")
	game.free()
	var restored = load("res://scenes/main.tscn").instantiate()
	restored.profile_path = path
	root.add_child(restored)
	restored.leaderboard.api_url = ""
	assert(is_equal_approx(restored.touch_control.sensitivity, 1.4) and restored.reduced_effects and restored.rewards.coins == 100, "Controls, effects and balance must survive reload")
	restored.free()
	DirAccess.remove_absolute(path)
	print("SETTINGS_EFFECTS_TEST_OK real_buttons practice_input isolation release_outside persistence case_only single_credit bounded_particles expiry visual_rng restart")
	quit()

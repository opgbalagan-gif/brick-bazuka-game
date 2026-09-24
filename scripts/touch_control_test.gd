extends SceneTree


func _init() -> void:
	run.call_deferred()


func touch(game, id: int, position: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	game._unhandled_input(event)


func drag(game, id: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = position
	game._unhandled_input(event)


func reset(game) -> void:
	game.start_game()
	game.blocks.clear()
	game.ghosts.clear()
	game.ghost_attack_timer = 1000
	game.spawn_cursor_y = -100000
	game.player_pos = Vector2(330, 600)
	game.player_vel = Vector2.ZERO


func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://touch_control_test.cfg"
	root.add_child(game)
	game.leaderboard.api_url = ""
	game.set_process(false)
	reset(game)
	touch(game, 0, Vector2(80, 600), true)
	game._process(0.05)
	assert(game.rockets.is_empty() and not game.tutorial_visible and game.player_vel.x == 0, "A new touch must wait to distinguish a tap from steering")
	drag(game, 0, Vector2(84, 602))
	touch(game, 0, Vector2(84, 602), false)
	assert(game.rockets.size() == 1 and game.rockets[0]["vel"].y > 0, "A short tap with hand jitter must fire one downward homing rocket")
	touch(game, 0, Vector2(84, 602), false)
	assert(game.rockets.size() == 1, "Duplicate release must not fire again")
	for fps in [30, 60, 120]:
		for direction in [-1, 1]:
			reset(game)
			var point := Vector2(80 if direction < 0 else 460, 600)
			touch(game, 0, point, true)
			for frame in int(fps * 0.4):
				game._process(1.0 / fps)
			assert(game.player_vel.x * direction > 250 and (game.player_pos.x - 330) * direction > 20, "Holding either half must move the hero at every frame rate")
			touch(game, 0, point, false)
			for frame in int(fps * 0.2):
				game._process(1.0 / fps)
			assert(is_zero_approx(game.player_vel.x) and game.rockets.is_empty(), "Releasing a hold must brake without shooting")
	reset(game)
	touch(game, 0, Vector2(200, 600), true)
	drag(game, 0, Vector2(280, 600))
	game._process(0.1)
	assert(game.player_vel.x > 0 and game.touch_control.axis == 1, "A right swipe must steer immediately even from the left half")
	drag(game, 0, Vector2(120, 600))
	game._process(0.2)
	assert(game.player_vel.x < 0 and game.touch_control.axis == -1, "Dragging back left must reverse steering")
	touch(game, 1, Vector2(420, 500), true)
	touch(game, 1, Vector2(420, 500), false)
	assert(game.rockets.size() == 1 and game.touch_control.axis == -1, "A second finger must shoot while the first keeps steering")
	touch(game, 0, Vector2(120, 600), false)
	assert(not game.touch_control.is_steering() and game.rockets.size() == 1, "Releasing the swipe must not add a shot")
	reset(game)
	touch(game, 0, Vector2(200, 600), true)
	drag(game, 0, Vector2(200, 680))
	touch(game, 0, Vector2(200, 680), false)
	assert(game.rockets.is_empty() and game.touch_control.axis == 0, "A vertical swipe must not accidentally shoot or steer sideways")
	touch(game, 0, Vector2(200, 600), true)
	touch(game, 0, Vector2(200, 600), false, true)
	assert(game.rockets.is_empty() and game.touch_control.touches.is_empty(), "Canceled taps must not shoot or retain input")
	touch(game, 0, Vector2(80, 600), true)
	game._process(0.2)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(not game.touch_control.is_steering(), "Leaving the app must clear held fingers")
	touch(game, 0, Vector2(80, 600), false)
	assert(game.rockets.is_empty(), "A stale release after losing focus must not shoot")
	touch(game, 0, Vector2(80, 600), true)
	game._process(0.2)
	game.paused = true
	game._process(0.1)
	assert(not game.touch_control.is_steering(), "Pause must clear touch steering")
	touch(game, 0, Vector2(200, 460), true)
	touch(game, 0, Vector2(200, 460), false)
	assert(not game.paused and game.rockets.is_empty(), "Touching resume must not also fire")
	touch(game, 0, Vector2(80, 600), true)
	game.finish_run()
	touch(game, 0, Vector2(80, 600), false)
	assert(game.touch_control.touches.is_empty() and game.rockets.is_empty(), "Results must release steering and ignore gameplay taps")
	reset(game)
	assert(game.touch_control.touches.is_empty(), "Restart must clear touch state")
	game.free()
	print("TOUCH_CONTROL_TEST_OK tap hold swipe reverse two_fingers cancel focus pause restart results fps_30_60_120")
	quit()

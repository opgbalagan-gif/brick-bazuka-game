extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _key(physical: Key, pressed: bool, logical: int = 0, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.keycode = physical if logical == 0 else logical
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://brick_keyboard_test.cfg"
	root.add_child(game)
	game.leaderboard.api_url = ""
	game.set_process(false)
	assert(game.tilt_control.uses_keyboard(), "Desktop builds must show keyboard instructions")
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, false)
	assert(game.screen == game.Screen.GAME and game.tutorial_visible, "Enter must start the game from the title")
	game.blocks.clear()
	game.ghosts.clear()
	game.spawn_cursor_y = -100000.0
	for physical in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D]:
		game.player_pos = Vector2(270, 500)
		game.player_vel = Vector2.ZERO
		game.tutorial_visible = true
		# Russian-layout logical characters must still use the physical A/D keys.
		var logical := 0x0424 if physical == KEY_A else 0x0412 if physical == KEY_D else 0
		_key(physical, true, logical)
		assert(not game.tutorial_visible, "The first steering key must dismiss the tutorial without a shot")
		var direction := -1.0 if physical in [KEY_LEFT, KEY_A] else 1.0
		assert(game.tilt_control.read_axis() == direction, "The real keyboard input must read the held direction")
		for frame in 12:
			game._process(1.0 / 60.0)
		assert((game.player_pos.x - 270) * direction > 30, "Held keys must move the hero in the requested direction")
		_key(physical, false, logical)
		assert(game.tilt_control.read_axis() == 0.0, "Releasing a key must release steering")
		for frame in 12:
			game._process(1.0 / 60.0)
		assert(is_zero_approx(game.player_vel.x), "The hero must brake after releasing movement keys")
	assert(game.rockets.is_empty(), "Movement keys must not fire")
	_key(KEY_A, true)
	_key(KEY_D, true)
	assert(game.tilt_control.read_axis() == 0.0, "Opposite keys must cancel each other")
	_key(KEY_A, false)
	assert(game.tilt_control.read_axis() == 1.0, "The remaining held key must keep working")
	_key(KEY_D, false)
	var velocity_before: Vector2 = game.player_vel
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	assert(game.rockets.size() == 1 and game.player_vel == velocity_before, "Space must fire without changing the jump or movement")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	assert(game.paused, "Escape must pause")
	_key(KEY_ESCAPE, true, 0, true)
	_key(KEY_ESCAPE, false)
	assert(game.paused, "Key repeats must not toggle pause repeatedly")
	_key(KEY_RIGHT, true)
	var position_before: Vector2 = game.player_pos
	game._process(0.2)
	assert(game.player_pos == position_before, "Movement keys must not move a paused game")
	_key(KEY_RIGHT, false)
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	assert(not game.paused and game.rockets.size() == 1, "Space must resume without firing an extra rocket")
	game.finish_run()
	_key(KEY_A, true)
	_key(KEY_A, false)
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	assert(game.screen == game.Screen.GAME_OVER, "Leaderboard typing must not restart the game or fire")
	game.free()
	DirAccess.remove_absolute("user://brick_keyboard_test.cfg")
	print("KEYBOARD_TEST_OK arrows_ad russian_layout tutorial movement release opposing_keys shoot pause resume results")
	quit()

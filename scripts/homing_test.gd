extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _reset(game) -> void:
	game.start_game()
	game.tutorial_visible = false
	game.blocks.clear()
	game.ghosts.clear()
	game.spawn_cursor_y = -100000.0
	game.player_pos = Vector2(270, 650)
	game.player_vel = Vector2(120, -80)


func _tap(game, position: Vector2, pressed: bool = true) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = pressed
	game._unhandled_input(event)


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://brick_homing_test.cfg"
	root.add_child(game)
	game.leaderboard.api_url = ""
	game.set_process(false)
	for frames_per_second in [15, 30, 60, 120]:
		for horizontal_speed in [-80.0, 80.0]:
			_reset(game)
			var target: Dictionary = game.make_ghost(Vector2(380 if horizontal_speed < 0 else 160, 300), horizontal_speed)
			var distant: Dictionary = game.make_ghost(Vector2(470, 50), 0)
			game.ghosts = [distant, target]
			game.blocks = [{"pos": target["pos"] - Vector2(90, 30), "size": Vector2(180, 60), "skin": 5, "kind": 1, "hp": 2, "max_hp": 2, "spring": true}]
			var platforms_before: Array = game.blocks.duplicate(true)
			var player_before: Vector2 = game.player_pos
			var velocity_before: Vector2 = game.player_vel
			game.tutorial_visible = true
			# Tapping directly on the farther ghost must still auto-select the nearest to the hero.
			_tap(game, distant["pos"])
			assert(game.rockets.size() == 1 and not game.tutorial_visible, "The first touch must fire immediately without waiting for release")
			assert(game.rockets[0]["target"] == target, "The nearest visible ghost must be selected regardless of the tap position")
			var direction: Vector2 = game.rockets[0]["vel"].normalized()
			assert(absf(angle_difference(game.visual_weapon_rotation, direction.angle())) < 0.001, "The bazooka must face the target when the rocket leaves the muzzle")
			_tap(game, Vector2(20, 900), false)
			var drag := InputEventScreenDrag.new()
			drag.position = Vector2(30, 700)
			game._unhandled_input(drag)
			_tap(game, Vector2(20, 900))
			assert(game.rockets.size() == 1, "Release, dragging and taps during reload must not duplicate the shot")
			var turned := false
			for frame in frames_per_second * 2:
				game.update_ghosts(1.0 / frames_per_second)
				game.update_rockets(1.0 / frames_per_second)
				if game.rockets.is_empty():
					break
				turned = turned or absf(angle_difference(direction.angle(), game.rockets[0]["vel"].angle())) > 0.01
				assert(absf(game.rockets[0]["vel"].length() - 690.0) < 0.1, "Homing must preserve rocket speed")
			assert(turned and game.rockets.is_empty() and not game.ghosts.has(target), "The rocket must turn in flight and hit the moving ghost at every tested frame rate")
			assert(game.ghosts.size() == 1 and game.ghost_deaths.size() == 1, "Only the nearby target must be defeated")
			assert(game.blocks == platforms_before, "Homing impacts must leave blocks and springs intact")
			assert(game.player_pos == player_before and game.player_vel == velocity_before, "Automatic targeting must not move the hero")
	_reset(game)
	var first_target: Dictionary = game.make_ghost(Vector2(240, 420), 0)
	var replacement: Dictionary = game.make_ghost(Vector2(450, 120), 0)
	game.ghosts = [first_target, replacement]
	_tap(game, Vector2(20, 900))
	var launch_origin: Vector2 = game.rockets[0]["sweep_origin"]
	game.shift_world(90)
	assert(game.rockets[0]["sweep_origin"] == launch_origin + Vector2(0, 90), "Camera scrolling must shift the pending launch collision with the rocket")
	game.update_rockets(0.1)
	game.pop_ghosts_near(first_target["pos"], 1.0)
	game.update_rockets(1.0 / 60.0)
	assert(game.rockets[0]["target"] == replacement, "A defeated target must be replaced by another live ghost")
	game.ghosts.clear()
	game.update_rockets(1.0 / 60.0)
	assert(game.rockets[0]["target"].is_empty(), "Dead ghosts must not remain homing targets")
	for frame in 150:
		game.update_rockets(1.0 / 60.0)
	assert(game.rockets.is_empty(), "A rocket with no targets must eventually expire")
	_reset(game)
	_tap(game, Vector2(30, 930))
	assert(game.rockets[0]["vel"].y < 0 and game.rockets[0]["target"].is_empty(), "With no visible ghosts, tapping anywhere must fire upward")
	var arriving: Dictionary = game.make_ghost(Vector2(400, 360), 0)
	game.ghosts = [arriving]
	game.update_rockets(0.05)
	assert(game.rockets[0]["target"] == arriving, "A rocket in flight must acquire a newly visible ghost")
	var rocket_position: Vector2 = game.rockets[0]["pos"]
	var rocket_velocity: Vector2 = game.rockets[0]["vel"]
	game.paused = true
	game._process(0.5)
	_tap(game, Vector2(10, 50))
	assert(game.rockets.size() == 1 and game.rockets[0]["pos"] == rocket_position and game.rockets[0]["vel"] == rocket_velocity, "Pausing must freeze homing and block taps")
	_reset(game)
	game.player_pos = Vector2(270, 100)
	var visible: Dictionary = game.make_ghost(Vector2(400, 500), 0)
	game.ghosts = [game.make_ghost(Vector2(270, -10), 0), visible]
	_tap(game, Vector2(30, 930))
	assert(game.rockets[0]["target"] == visible, "Unseen ghosts above the screen must not steal the tap target")
	_reset(game)
	game.ghosts = [game.make_ghost(game.get_weapon_pivot() + Vector2(0, -10), 0)]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(20, 900)
	click.pressed = true
	game._unhandled_input(click)
	assert(game.rockets.size() == 1, "A mouse click must fire immediately too")
	click.pressed = false
	game._unhandled_input(click)
	assert(game.rockets.size() == 1, "Mouse release must not fire a second rocket")
	game.update_rockets(1.0 / 60.0)
	assert(game.ghosts.is_empty(), "A ghost closer than the muzzle must still be hit")
	_reset(game)
	game.ghosts = [game.make_ghost(Vector2(270, 600), 0)]
	game.rockets = [{"pos": Vector2(270, 700), "vel": Vector2(0, -690), "life": 2.2, "trail": 0.0}]
	game.update_rockets(0.3)
	assert(game.ghosts.is_empty() and game.rockets.is_empty(), "A long frame must not let rockets tunnel through a ghost")
	game.free()
	DirAccess.remove_absolute("user://brick_homing_test.cfg")
	print("HOMING_TEST_OK immediate_tap click nearest_visible moving_target retarget no_target close_range swept_hit pause platforms_safe fps_15_30_60_120")
	quit()

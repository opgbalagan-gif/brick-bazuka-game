extends SceneTree


func _init() -> void:
	run.call_deferred()


func reset(game) -> void:
	game.start_game()
	game.tutorial_visible = false
	game.blocks.clear()
	game.ghosts.clear()
	game.ghost_attack_timer = 1000.0
	game.spawn_cursor_y = -100000.0
	game.player_pos = Vector2(330, 650)
	game.player_vel = Vector2.ZERO


func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://weapon_pose_test.cfg"
	root.add_child(game)
	game.leaderboard.api_url = ""
	game.set_process(false)
	var cases := [
		[Vector2(0, -260), Vector2.UP], [Vector2(0, 260), Vector2.DOWN],
		[Vector2(-260, 0), Vector2.LEFT], [Vector2(260, 0), Vector2.RIGHT],
		[Vector2(-80, -260), Vector2.UP], [Vector2(80, 260), Vector2.DOWN],
		[Vector2(-260, -80), Vector2.LEFT], [Vector2(260, 80), Vector2.RIGHT]
	]
	for fps in [15, 30, 60, 120]:
		for pose in cases:
			reset(game)
			assert(is_zero_approx(game.visual_weapon_rotation), "The starting rest pose must be horizontal")
			var offset: Vector2 = pose[0]
			var direction: Vector2 = pose[1]
			var ghost: Dictionary = game.make_ghost(game.get_weapon_pivot() + offset, 0)
			game.ghosts = [ghost]
			game.launch_player()
			var shot_angle: float = direction.angle()
			assert(absf(angle_difference(game.visual_weapon_rotation, shot_angle)) < 0.001, "The barrel must choose up, down, left or right toward the ghost")
			assert(game.rockets[0]["vel"].normalized().is_equal_approx(direction), "The rocket must follow the cardinal barrel direction at launch")
			assert(game.rockets[0]["pos"].is_equal_approx(game.get_weapon_pivot() + direction * 68.0), "The rocket must start at the muzzle after the hero turns")
			if direction.x != 0.0:
				assert(game.facing_left == (direction.x < 0.0) and game.weapon_anchor_x * direction.x > 0.0, "Horizontal shots must turn the whole hero and grip toward the shot")
			var initial_rest: float = PI if game.facing_left else 0.0
			var initial_turn: float = absf(angle_difference(shot_angle, initial_rest))
			var previous_error := initial_turn
			for frame in range(1, fps + 1):
				var elapsed: float = float(frame) / fps
				# Even if the target crosses the hero or the hero turns, keep the shot angle.
				ghost["pos"] = game.get_weapon_pivot() - offset
				game.player_vel.x = -220.0 if elapsed <= 0.20 and frame % 2 == 0 else 220.0
				game.update_rockets(1.0 / fps)
				game.update_visual_controller(1.0 / fps)
				var rest_angle: float = PI if game.facing_left else 0.0
				var error: float = absf(angle_difference(game.visual_weapon_rotation, rest_angle))
				if elapsed < 0.44 and direction.x != 0.0:
					assert(game.facing_left == (direction.x < 0.0), "Movement must not turn the hero away during a horizontal shot")
				if elapsed <= 0.20:
					assert(absf(angle_difference(game.visual_weapon_rotation, shot_angle)) < 0.001, "The held angle must not follow the target, rocket or body lean")
				elif elapsed < 0.44:
					assert(error <= previous_error + 0.001, "The return must move smoothly toward rest without reversing")
					if initial_turn > 0.1:
						assert(error > 0.001 and error < initial_turn, "The return must pass through intermediate angles")
				else:
					assert(error < 0.001, "The weapon must finish at its exact horizontal rest angle")
				previous_error = error
	# Exercise the actual game loop for pause, reload, repeat shots and restart.
	reset(game)
	game.ghosts = [game.make_ghost(game.get_weapon_pivot() + Vector2.UP * 260, 0)]
	game.launch_player()
	game._process(0.1)
	var held_angle: float = game.visual_weapon_rotation
	var held_time: float = game.weapon_pose_timer
	game.launch_player()
	assert(game.rockets.size() == 1 and game.weapon_pose_timer == held_time, "Reload taps must not restart the pose or create a second rocket")
	game.paused = true
	game._process(0.8)
	assert(game.visual_weapon_rotation == held_angle and game.weapon_pose_timer == held_time, "Pause must freeze the pose, including its remaining hold")
	game.paused = false
	game._process(0.15)
	assert(game.visual_weapon_rotation != held_angle, "Resuming must continue into the smooth return")
	game._process(0.3)
	assert(is_zero_approx(game.visual_weapon_rotation), "The actual game loop must complete the horizontal return")
	game.ghosts = [game.make_ghost(game.get_weapon_pivot() + Vector2(80, -260), 0)]
	game.launch_player()
	assert(game.visual_weapon_rotation < 0.0 and game.weapon_pose_timer > 0.4, "The next allowed shot must lock its new direction")
	game.start_game()
	assert(game.weapon_pose_timer == 0.0 and game.aim_direction == Vector2.RIGHT and is_zero_approx(game.visual_weapon_rotation), "Restart must clear the previous shot pose and restore horizontal rest")
	reset(game)
	game.player_vel.x = -220.0
	game.update_visual_controller(0.5)
	assert(absf(angle_difference(game.visual_weapon_rotation, PI)) < 0.001, "The resting weapon must remain horizontal when the hero faces left")
	game.ghosts = [game.make_ghost(game.get_weapon_pivot() + Vector2.UP * 260, 0)]
	game.launch_player()
	game.update_visual_controller(0.5)
	assert(absf(angle_difference(game.visual_weapon_rotation, PI)) < 0.001, "A left-facing hero must return to the leftward horizontal rest pose after firing")
	reset(game)
	game.launch_player(Vector2(20, 20))
	assert(game.aim_direction == Vector2.DOWN, "With no ghosts, tap position must not change the downward shot")
	game.update_visual_controller(0.5)
	assert(is_zero_approx(game.visual_weapon_rotation), "An empty downward shot must also return to horizontal rest")
	game.free()
	DirAccess.remove_absolute("user://weapon_pose_test.cfg")
	print("WEAPON_POSE_TEST_OK horizontal_rest four_directions diagonal_selection hold moving_target body_turn smooth_return pause reload repeat restart no_target fps_15_30_60_120")
	quit()

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
	for fps in [15, 30, 60, 120]:
		for offset in [Vector2.UP * 260, Vector2.DOWN * 260, Vector2(-210, -180), Vector2(210, 180)]:
			reset(game)
			var ghost: Dictionary = game.make_ghost(game.get_weapon_pivot() + offset, 0)
			game.ghosts = [ghost]
			game.launch_player()
			var shot_angle: float = offset.angle()
			assert(absf(angle_difference(game.visual_weapon_rotation, shot_angle)) < 0.001, "The barrel must point toward the ghost at launch, above or below")
			assert(game.rockets[0]["vel"].normalized().is_equal_approx(offset.normalized()), "The rocket must follow the barrel at launch")
			var initial_turn: float = absf(angle_difference(shot_angle, PI * 0.5))
			var previous_error := initial_turn
			for frame in range(1, fps + 1):
				# Even if the target crosses the hero or the hero turns, keep the shot angle.
				ghost["pos"] = game.get_weapon_pivot() - offset
				game.player_vel.x = -220.0 if frame % 2 == 0 else 220.0
				game.update_rockets(1.0 / fps)
				game.update_visual_controller(1.0 / fps)
				var elapsed: float = float(frame) / fps
				var error: float = absf(angle_difference(game.visual_weapon_rotation, PI * 0.5))
				if elapsed <= 0.20:
					assert(absf(angle_difference(game.visual_weapon_rotation, shot_angle)) < 0.001, "The held angle must not follow the target, rocket or body lean")
				elif elapsed < 0.44:
					assert(error <= previous_error + 0.001, "The return must move smoothly toward rest without reversing")
					if initial_turn > 0.1:
						assert(error > 0.001 and error < initial_turn, "The return must pass through intermediate angles")
				else:
					assert(error < 0.001, "The weapon must finish at its exact downward rest angle")
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
	assert(absf(angle_difference(game.visual_weapon_rotation, PI * 0.5)) < 0.001, "The actual game loop must complete the return")
	game.ghosts = [game.make_ghost(game.get_weapon_pivot() + Vector2(200, -180), 0)]
	game.launch_player()
	assert(game.visual_weapon_rotation < 0.0 and game.weapon_pose_timer > 0.4, "The next allowed shot must lock its new direction")
	game.start_game()
	assert(game.weapon_pose_timer == 0.0 and game.aim_direction == Vector2.DOWN and is_equal_approx(game.visual_weapon_rotation, PI * 0.5), "Restart must clear the previous shot pose")
	reset(game)
	game.launch_player(Vector2(20, 20))
	assert(game.aim_direction == Vector2.DOWN, "With no ghosts, tap position must not change the downward shot")
	game.free()
	DirAccess.remove_absolute("user://weapon_pose_test.cfg")
	print("WEAPON_POSE_TEST_OK up_down_diagonal hold moving_target body_turn smooth_return pause reload repeat restart no_target fps_15_30_60_120")
	quit()

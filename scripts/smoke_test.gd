extends SceneTree


class TiltStub extends Node:
	var axis := 0.0
	var blocking := false
	func start() -> void:
		axis = 0.0
		blocking = false
	func stop() -> void:
		axis = 0.0
	func read_axis() -> float:
		return axis
	func needs_permission() -> bool:
		return blocking
	func uses_keyboard() -> bool:
		return true


func _use_tilt_stub(game) -> void:
	game.tilt_control.free()
	game.tilt_control = TiltStub.new()
	game.add_child(game.tilt_control)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var legacy_profile := ConfigFile.new()
	legacy_profile.set_value("progress", "money", 99999)
	legacy_profile.set_value("progress", "upgrades", {"boots": 20, "bazooka": 20})
	legacy_profile.set_value("progress", "cash_total", 50)
	legacy_profile.set_value("progress", "best_meters", 123)
	var test_profile_path := "user://brick_bazuka_smoke_save.cfg"
	legacy_profile.save(test_profile_path)
	var packed: PackedScene = load("res://scenes/main.tscn")
	assert(packed != null, "Main scene must load")
	var game = packed.instantiate()
	game.profile_path = test_profile_path
	root.add_child(game)
	_use_tilt_stub(game)
	game.leaderboard.api_url = ""
	assert(game.background_video != null and game.background_video.loop, "Background video must be ready to loop")
	assert(not game.background_video.is_playing(), "Title screen must not decode the game background")
	game.handle_menu_press(Vector2(40, 40))
	assert(game.screen == 0, "Removed menu controls must not respond")
	game.handle_menu_press(Vector2(270, 905))
	assert(game.screen == 0, "The old bottom navigation must not start the game")
	game.handle_menu_press(game.cta_rect.get_center())
	assert(game.screen == 1, "The painted START button must launch the game")
	game.start_game()
	assert(game.best_meters == 123, "Existing height records must survive removal of currency")
	assert(game.blocks.size() == 4, "The opening must contain four single platform rows")
	for index in range(1, game.blocks.size()):
		var gap: float = game.blocks[index - 1]["pos"].y - game.blocks[index]["pos"].y
		assert(gap >= 250 and gap <= 310, "Platforms must keep the larger vertical gaps")
	game.blocks.clear()
	for row in 50:
		var before: int = game.blocks.size()
		game.spawn_block(-row * 280.0)
		var new_blocks: Array = game.blocks.slice(before)
		assert(new_blocks.size() >= 1 and new_blocks.size() <= 2, "A row must contain a safe platform and at most one decoy")
		assert(new_blocks.filter(func(item): return not item.get("fake", false)).size() == 1, "Every generated row must retain a safe landing")
		var block: Dictionary = game.blocks.back()
		var source: Rect2 = game.PLATFORM_ART[block["skin"]]["region"]
		assert(absf(block["size"].aspect() - source.size.aspect()) < 0.01, "Platform artwork must retain its proportions")
	game.start_game()
	game.tutorial_visible = false
	game.sync_video_background()
	assert(game.background_video.is_playing() and not game.background_video.paused, "The level must play the background video")
	game.player_pos = Vector2(270, 460)
	game.player_vel = Vector2.ZERO
	var shot_target: Vector2 = game.player_pos + Vector2(140, 240)
	game.ghosts = [game.make_ghost(shot_target, 0)]
	game.update_aim_target(shot_target)
	assert(not game.facing_left, "Firing must preserve the idle hero's facing")
	var solution: Dictionary = game.get_aim_solution(game.get_weapon_pivot() + Vector2.DOWN * 260.0)
	var expected_shot_direction: Vector2 = solution["direction"]
	game.launch_player(shot_target)
	assert(game.rockets.size() == 1, "A shot must create one rocket")
	assert(game.rockets[0]["pos"].distance_to(solution["muzzle"]) < 0.01, "Rocket must spawn at the rotating muzzle")
	assert(game.rockets[0]["vel"].normalized().dot(expected_shot_direction) > 0.99, "Rocket must leave the bazooka downward before homing")
	assert(game.player_vel == Vector2.ZERO, "Firing down-right must not move the hero")
	var rocket_count: int = game.rockets.size()
	game.launch_player(shot_target)
	assert(game.rockets.size() == rocket_count, "Reload must block immediate shot spam")
	game.reload_timer = 0.0
	game.player_vel = Vector2.ZERO
	var down_target: Vector2 = game.player_pos + Vector2(0, 260)
	game.ghosts = [game.make_ghost(down_target, 0)]
	game.update_aim_target(down_target)
	var down_solution: Dictionary = game.get_aim_solution(down_target)
	game.launch_player(down_target)
	assert(absf(down_solution["direction"].x) < 0.12 and game.player_vel == Vector2.ZERO, "Downward shots must preserve player velocity")
	game.reload_timer = 0.0
	game.player_vel = Vector2.ZERO
	var left_target: Vector2 = game.player_pos + Vector2(-140, 240)
	game.ghosts = [game.make_ghost(left_target, 0)]
	game.update_aim_target(left_target)
	assert(not game.facing_left, "Shooting left must not turn a stationary hero")
	game.launch_player(left_target)
	assert(game.player_vel == Vector2.ZERO, "Firing down-left must not move the hero")

	var smashed_before: int = game.smashed_total
	game.damage_block(0, 99)
	assert(game.smashed_total == smashed_before + 1, "Brick destruction must advance the destruction count")
	game.blocks = [{"pos": Vector2(220, 610), "size": Vector2(180, 61), "skin": 5, "kind": 1, "hp": 2, "max_hp": 2}]
	game.player_pos = Vector2(270, 560)
	game.player_vel = Vector2(0, 180)
	game.check_player_block_collisions()
	assert(game.blocks.size() == 1 and game.blocks[0]["hp"] == 1, "Reinforced stone must survive the first landing with visible cracks")
	game.player_pos = Vector2(270, 560)
	game.player_vel = Vector2(0, 180)
	game.check_player_block_collisions()
	assert(game.blocks.is_empty(), "The second landing must destroy reinforced stone")
	game.blocks = [{"pos": Vector2(220, 610), "size": Vector2(120, 52), "kind": 0, "hp": 1, "max_hp": 1}]
	game.player_pos = Vector2(270, 560)
	game.player_vel = Vector2(0, 180)
	game.visual_body_rotation = deg_to_rad(42.0)
	game.check_player_block_collisions()
	assert(game.player_vel.y < 0, "The first controller platform bounce must be restored")

	var aim_sequence := [Vector2(-130, 250), Vector2(130, 250), Vector2(0, 260), Vector2(-130, 250)]
	for offset in aim_sequence:
		game.update_aim_target(game.player_pos + offset)
		for frame in 5:
			game.update_visual_controller(1.0 / 60.0)
		assert(absf(game.visual_body_rotation) <= deg_to_rad(50.1), "Body lean must remain controlled")
		assert(is_finite(game.visual_weapon_rotation), "Weapon rotation must remain stable")
	game.update_aim_target(game.player_pos + Vector2(130, 250))
	game.player_vel.x = 220
	game.update_visual_controller(0.12)
	assert(game.visual_body_rotation > 0, "Rightward movement must lean the body clockwise")
	var weapon_error := absf(angle_difference(game.visual_weapon_rotation, game.aim_direction.angle()))
	assert(weapon_error < 0.25, "Bazooka must track the aim quickly")
	var right_draw_state: Dictionary = game.get_weapon_draw_state()
	assert(right_draw_state["scale"].x < 0, "Right-facing bazooka must use a horizontal mirror")
	assert(absf(wrapf(right_draw_state["rotation"], -PI, PI)) <= PI * 0.5, "Right-facing bazooka must stay upright")
	game.update_aim_target(game.player_pos + Vector2(-130, 250))
	var pivot_before_flip: Vector2 = game.get_weapon_pivot()
	game.update_aim_target(game.player_pos + Vector2(130, 250))
	var pivot_before_smoothing: Vector2 = game.get_weapon_pivot()
	assert(pivot_before_flip.distance_to(pivot_before_smoothing) < 0.01, "Flip must not teleport the weapon anchor")
	game.update_aim_target(game.player_pos + Vector2(-130, 250))
	game.player_vel.x = -220
	for frame in 12:
		game.update_visual_controller(1.0 / 60.0)
	assert(game.visual_body_rotation < 0, "Leftward movement must lean the body counter-clockwise")
	assert(game.weapon_anchor_x < 0, "The bazooka grip must move to the hero's left-facing hand")
	var left_draw_state: Dictionary = game.get_weapon_draw_state()
	assert(left_draw_state["scale"].x > 0, "Left-facing bazooka must use its original readable orientation")
	assert(absf(wrapf(left_draw_state["rotation"], -PI, PI)) <= PI * 0.5, "Left-facing bazooka must stay upright")
	game.update_aim_target(game.player_pos + Vector2(130, 250))
	game.player_vel.x = 220
	for frame in 24:
		game.update_visual_controller(1.0 / 60.0)
	assert(not game.facing_left and game.weapon_anchor_x > 0, "Rightward movement must flip the hero and grip together")

	game.start_game()
	game.tutorial_visible = false
	game.blocks.clear()
	game.ghosts = [{"pos": Vector2(180, 250), "vx": 45.0, "phase": 0.0, "variant": 0}]
	game.update_ghosts(0.1)
	assert(game.ghosts[0]["pos"].x > 180, "Ghosts must drift during a run")
	var ghost_position: Vector2 = game.ghosts[0]["pos"]
	game.rockets = [{"pos": ghost_position - Vector2(0, 10), "vel": Vector2(0, 690), "life": 2.0, "trail": 0.0}]
	game.update_rockets(1.0 / 60.0)
	assert(game.ghosts.is_empty() and game.rockets.is_empty(), "A rocket must pop a ghost")
	assert(game.ghost_deaths.size() == 1, "A popped ghost must start the supplied death clip")
	game.pop_ghosts_near(ghost_position, 80)
	assert(game.ghost_deaths.size() == 1, "An already defeated ghost must not restart its death clip")
	game.update_ghost_deaths(0.5)
	game.shift_world(65)
	assert(game.ghost_deaths[0]["pos"].distance_to(ghost_position + Vector2(0, 65)) < 0.01, "Death effects must follow world scrolling")
	game.ghosts = [{"pos": Vector2(200, 250), "vx": 0.0, "phase": 0.0, "variant": 1}]
	game.pop_ghosts_near(Vector2(220, 250), 60.0)
	assert(game.ghosts.is_empty(), "Nearby explosions must pop ghosts too")
	assert(game.ghost_deaths.size() == 2, "Each defeated ghost must have its own death playback")
	game.update_ghost_deaths(2.0)
	assert(game.ghost_deaths.is_empty(), "Completed death clips must disappear, not loop")
	game.player_pos = Vector2(270, 460)
	game.ghosts = [{"pos": game.player_pos + Vector2(0, -7), "vx": 0.0, "phase": 0.0, "variant": 2}]
	game.check_player_ghost_collisions()
	assert(game.health == 2, "The first ghost touch must immediately remove one visible heart")
	game.check_player_ghost_collisions()
	assert(game.health == 2, "Contact cooldown must prevent repeated damage each frame")
	game.contact_cooldown = 0.0
	game.check_player_ghost_collisions()
	assert(game.health == 1, "A second ghost hit must leave one heart")
	game.contact_cooldown = 0.0
	game.check_player_ghost_collisions()
	assert(game.health == 0 and game.screen == 2, "The third ghost hit must end the run with no hearts")
	game.check_player_ghost_collisions()
	assert(game.health == 0, "Finished runs must not consume extra lives")
	game.start_game()
	game.tutorial_visible = false
	game.height_meters = 88
	for expected_health in [2, 1, 0]:
		game.respawn_timer = 0.0
		game.player_pos = Vector2(270, game.WORLD_SIZE.y + 81)
		game.player_vel = Vector2.ZERO
		# A ghost at the fall boundary must not charge a second life in the same frame.
		game.ghosts = [game.make_ghost(game.player_pos + Vector2(0, -7), 0.0)]
		game.update_game(1.0 / 60.0)
		assert(game.health == expected_health, "Each fall must consume exactly one heart, including the first")
		assert(game.height_meters == 88, "Recovering from a fall must retain the run score")
		if expected_health > 0:
			assert(game.screen == 1 and game.player_pos.y < 960 and game.respawn_timer > 0.0, "Remaining lives must return the player onto a platform")
			assert(game.contact_cooldown > 0, "Returning after a fall must give brief protection from ghosts")
			game.ghosts = [game.make_ghost(game.player_pos + Vector2(0, -7), 0.0)]
			game.check_player_ghost_collisions()
			assert(game.health == expected_health, "A ghost at the return position must not remove another heart immediately")
		else:
			assert(game.screen == 2 and game.leaderboard.visible, "The last fall must open the leaderboard")
	print("HEALTH_TEST_OK first_hit cooldown three_falls score_preserved final_leaderboard")
	game.start_game()
	game.tutorial_visible = false
	assert(game.health == 3, "Restart must restore all three hearts")
	assert(game.ghost_deaths.is_empty(), "Restart must clear death effects")
	game.player_pos = Vector2(270, 550)
	var animated_ghost: Dictionary = game.make_ghost(Vector2(270, 200), 0.0)
	game.ghosts = [animated_ghost]
	game.update_ghosts(0.1)
	assert(animated_ghost["state"] == "idle", "A distant ghost must use the calm clip")
	game.player_pos = animated_ghost["pos"] + Vector2(0, 170)
	game.update_ghosts(0.1)
	assert(animated_ghost["state"] == "alert", "Approaching a ghost must activate the angry clip")
	game.player_pos = animated_ghost["pos"] + Vector2(0, 225)
	game.update_ghosts(0.1)
	assert(animated_ghost["state"] == "alert", "Small movements near the threshold must not flicker states")
	game.player_pos = animated_ghost["pos"] + Vector2(0, 300)
	game.update_ghosts(0.1)
	assert(animated_ghost["state"] == "idle", "Moving away must restore the calm clip")
	game.spawn_ghost_pop(Vector2(160, 240))
	game.paused = true
	var animation_before: float = animated_ghost["animation_time"]
	game._process(0.2)
	assert(animated_ghost["animation_time"] == animation_before and game.ghost_deaths[0]["time"] == 0.0, "Pause must freeze live and death animations")
	assert(game.background_video.paused, "Pause must freeze the video too")
	game.return_to_menu()
	assert(not game.background_video.is_playing() and not game.background_layer.visible, "Returning to START must stop the background")
	game.start_game()
	game.tutorial_visible = false
	game.ghosts.clear()

	game.player_pos = Vector2(270, 300)
	game.player_vel = Vector2(0, -360)
	game.update_game(1.0 / 60.0)
	assert(game.height_meters > 0, "Upward movement must advance height")
	for frame in 180:
		if frame % 24 == 0:
			game.reload_timer = 0.0
			game.launch_player(game.player_pos + Vector2(-120 if frame % 48 == 0 else 120, 260))
		game.update_game(1.0 / 60.0)
	assert(game.blocks.size() > 0, "Procedural world must contain blocks")
	assert(game.rockets.size() >= 0, "Rocket update completed")
	_test_tilt_steering(game)
	_test_screen_wrap(game)
	_test_moving_platforms(game)
	_test_platform_jump(game)
	_test_single_spring_jump(game)
	_test_spring_rarity(game)
	_test_fast_ghost_death(game)
	_test_rockets_ignore_platforms(game)
	_test_shots_preserve_motion(game)
	game.save_profile()
	var saved_profile := ConfigFile.new()
	assert(saved_profile.load(test_profile_path) == OK, "Updated profile must save")
	assert(saved_profile.get_section_keys("progress").size() == 2, "Only height and destruction count must persist as progress")
	assert(not saved_profile.has_section_key("progress", "money") and not saved_profile.has_section_key("progress", "upgrades"), "Old currency and upgrades must be removed from saved profiles")
	print("SMOKE_TEST_OK platforms=sparse stone=two_hits economy=removed controller=preserved animations=working height=", int(game.height_meters))
	game.free()
	DirAccess.remove_absolute(test_profile_path)
	quit(0)


func _test_tilt_steering(game) -> void:
	game.start_game()
	game.tutorial_visible = false
	game.blocks.clear()
	game.ghosts.clear()
	game.spawn_cursor_y = -100000.0
	game.player_pos = Vector2(270, 450)
	game.player_vel = Vector2.ZERO
	game.tilt_control.axis = 1.0
	for frame in 30:
		game._process(1.0 / 60.0)
	assert(game.player_pos.x > 380 and game.player_vel.x > 0, "Right tilt must move the hero right")
	game.tilt_control.axis = 0.0
	for frame in 12:
		game._process(1.0 / 60.0)
	assert(is_zero_approx(game.player_vel.x), "Neutral phone position must stop horizontal drift")
	game.tilt_control.axis = -1.0
	for frame in 24:
		game._process(1.0 / 60.0)
	assert(game.player_pos.x < 350 and game.player_vel.x < 0, "Left tilt must reverse horizontal movement")
	var position_before: Vector2 = game.player_pos
	game.paused = true
	game._process(0.2)
	assert(game.player_pos == position_before, "Tilt must not move a paused game")
	game.paused = false
	game.tilt_control.blocking = true
	game._process(0.2)
	assert(game.player_pos == position_before, "Game must wait while the sensor permission dialog is open")
	game.tilt_control.blocking = false
	assert(game.rockets.is_empty(), "Tilting must not fire the bazooka")
	print("TILT_GAME_TEST_OK left_right braking pause permission no_shots")


func _test_screen_wrap(game) -> void:
	for frames_per_second in [30, 60, 120]:
		for direction in [-1.0, 1.0]:
			game.start_game()
			game.tutorial_visible = false
			game.blocks.clear()
			game.ghosts.clear()
			game.spawn_cursor_y = -100000.0
			game.player_pos = Vector2(1 if direction < 0 else game.WORLD_SIZE.x - 1, 500)
			game.player_vel = Vector2(direction * game.STEERING_SPEED, -100)
			game.tilt_control.axis = direction
			var delta := 1.0 / float(frames_per_second)
			game.update_game(delta)
			if direction < 0:
				assert(game.player_pos.x > game.WORLD_SIZE.x - 11 and game.player_pos.x < game.WORLD_SIZE.x, "Leaving the left edge must enter from the right")
			else:
				assert(game.player_pos.x > 0 and game.player_pos.x < 11, "Leaving the right edge must enter from the left")
			assert(is_equal_approx(game.player_vel.x, direction * game.STEERING_SPEED), "Wrapping must preserve horizontal speed and direction")
			var expected_vertical_speed: float = -100 + game.PLAYER_GRAVITY * delta
			assert(is_equal_approx(game.player_vel.y, expected_vertical_speed), "Wrapping must preserve the jump")
			assert(is_equal_approx(game.player_pos.y, 500 + expected_vertical_speed * delta), "Wrapping must not teleport vertically")
			assert(game.health == 3 and is_zero_approx(game.height_meters), "Crossing a side must not cost a life or award height")
	print("SCREEN_WRAP_TEST_OK both_directions fps_30_60_120 velocity_jump_health_preserved")


func _test_moving_platforms(game) -> void:
	game.start_game()
	var initial_blocks: Array = game.blocks.duplicate(true)
	assert(is_equal_approx(game.blocks[0]["pos"].x + game.blocks[0]["size"].x * 0.5, game.player_pos.x), "The first moving platform must start beneath the hero")
	game._process(0.2)
	assert(game.blocks == initial_blocks, "Platforms must wait while the introductory hint is open")
	game.tutorial_visible = false
	game.paused = true
	game._process(0.2)
	assert(game.blocks == initial_blocks, "Pause must freeze moving platforms")
	game.paused = false
	game.tilt_control.blocking = true
	game._process(0.2)
	assert(game.blocks == initial_blocks, "Sensor permission must freeze moving platforms")
	game.tilt_control.blocking = false
	var moved_left := false
	var moved_right := false
	for frame in 900:
		var previous_x: float = game.blocks[0]["pos"].x
		game.update_platforms(1.0 / 30.0)
		moved_left = moved_left or game.blocks[0]["pos"].x < previous_x - 0.01
		moved_right = moved_right or game.blocks[0]["pos"].x > previous_x + 0.01
		for index in game.blocks.size():
			var block: Dictionary = game.blocks[index]
			assert(block["pos"].x >= 21.99 and block["pos"].x + block["size"].x <= game.WORLD_SIZE.x - 21.99, "The full platform must remain inside the screen")
			assert(block["pos"].y == initial_blocks[index]["pos"].y, "Horizontal motion must preserve platform heights")
			if block["spring"]:
				assert(is_equal_approx(game.spring_rect(block).get_center().x, block["pos"].x + block["size"].x * 0.5), "The spring must stay attached to its moving platform")
	assert(moved_left and moved_right, "Platforms must travel both left and right")
	var positions_at_30_fps: Array = []
	for frames_per_second in [30, 60, 120]:
		game.blocks = initial_blocks.duplicate(true)
		for frame in frames_per_second * 4:
			game.update_platforms(1.0 / frames_per_second)
		for index in game.blocks.size():
			if frames_per_second == 30:
				positions_at_30_fps.append(game.blocks[index]["pos"])
			else:
				assert(game.blocks[index]["pos"].distance_to(positions_at_30_fps[index]) < 0.01, "Platform motion must be consistent across frame rates")
	var x_before_scroll: float = game.blocks[0]["pos"].x
	var y_before_scroll: float = game.blocks[0]["pos"].y
	game.shift_world(80)
	game.update_platforms(0.0)
	assert(is_equal_approx(game.blocks[0]["pos"].x, x_before_scroll) and is_equal_approx(game.blocks[0]["pos"].y, y_before_scroll + 80), "Camera scrolling must preserve the platform's horizontal path")
	# Move a spring far from its original position and land on its new location.
	var moving_spring := {"pos": Vector2(100, 650), "size": Vector2(150, 60), "skin": 5, "kind": 1, "hp": 2, "max_hp": 2, "spring": true,
		"motion_center": 200.0, "motion_amplitude": 100.0, "motion_phase": PI * 1.5, "motion_rate": 0.5}
	game.blocks = [moving_spring]
	game.update_platforms(TAU)
	game.player_pos = Vector2(375, 550)
	game.player_vel = Vector2(0, 180)
	game.check_player_block_collisions()
	assert(is_equal_approx(game.player_vel.y, -game.SPRING_BOUNCE_SPEED) and not moving_spring["spring"], "Spring collisions must follow the moving artwork")
	game.ghosts.clear()
	var impact: Vector2 = moving_spring["pos"] + moving_spring["size"] * 0.5
	game.rockets = [{"pos": impact, "vel": Vector2.ZERO, "life": 1.0, "trail": 0.0}]
	game.update_rockets(1.0 / 60.0)
	assert(game.blocks.size() == 1 and moving_spring["hp"] == 1 and game.rockets.size() == 1, "A rocket inside the moving platform must leave its health unchanged and continue flying")
	print("MOVING_PLATFORMS_TEST_OK left_right bounds pause spring_contact rocket_pass_through scroll fps_30_60_120")


func _test_platform_jump(game) -> void:
	for frames_per_second in [30, 60, 120]:
		for gap in [game.BLOCK_GAP_MIN, (game.BLOCK_GAP_MIN + game.BLOCK_GAP_MAX) * 0.5, game.BLOCK_GAP_MAX]:
			game.start_game()
			game.tutorial_visible = false
			game.ghosts.clear()
			game.spawn_cursor_y = -100000.0
			var next_platform := {"pos": Vector2(205, 760 - gap), "size": Vector2(130, 44), "skin": 5, "kind": 1, "hp": 2, "max_hp": 2,
				"motion_center": 205.0, "motion_amplitude": 70.0, "motion_phase": 0.0, "motion_rate": 0.6}
			game.blocks = [
				{"pos": Vector2(205, 760), "size": Vector2(130, 44), "skin": 0, "kind": 0, "hp": 1, "max_hp": 1},
				next_platform
			]
			game.player_pos = Vector2(270, 700)
			game.player_vel = Vector2(0, 180)
			var cleared_next_platform := false
			var landed_on_next_platform := false
			for frame in frames_per_second * 4:
				game._process(1.0 / frames_per_second)
				if game.player_pos.y + 68 < next_platform["pos"].y:
					cleared_next_platform = true
				if next_platform["hp"] == 1:
					landed_on_next_platform = true
					break
			assert(cleared_next_platform, "Platform jump must clear the next surface at every generated vertical gap")
			assert(landed_on_next_platform and game.player_vel.y < 0, "Hero must land on and bounce from the next platform")
			assert(game.health == 3 and game.rockets.is_empty(), "Reaching the next platform must need no shots or lost lives")
	print("PLATFORM_JUMP_TEST_OK gaps_250_280_310 fps_30_60_120 landing_without_shots")


func _spring_test_platform(has_spring: bool = true) -> Dictionary:
	return {"pos": Vector2(150, 700), "size": Vector2(240, 65), "skin": 5, "kind": 1, "hp": 2, "max_hp": 2, "spring": has_spring}


func _test_single_spring_jump(game) -> void:
	game.start_game()
	assert(game.blocks[2]["spring"], "A spring must be discoverable on the third opening platform")
	var last_spring_row := -1
	var spring_count := 0
	for row in 60:
		var ghosts_before: int = game.ghosts.size()
		game.spawn_block(-row * 280.0)
		if game.blocks.back()["spring"]:
			assert(game.ghosts.size() == ghosts_before, "Spring takeoff must not spawn a ghost on top of the pickup")
			if last_spring_row >= 0:
				assert(row - last_spring_row >= 5 and row - last_spring_row <= 7, "Springs must keep appearing every five to seven platforms")
			last_spring_row = row
			spring_count += 1
	assert(spring_count >= 8, "A long run must contain repeated spring opportunities")
	for frames_per_second in [30, 60, 120]:
		game.start_game()
		game.tutorial_visible = false
		game.ghosts.clear()
		game.spawn_cursor_y = -100000.0
		var spring_platform := _spring_test_platform()
		game.blocks = [spring_platform]
		game.player_pos = Vector2(270, 600)
		game.player_vel = Vector2(0, -100)
		game.check_player_block_collisions()
		assert(game.player_vel.y == -100 and spring_platform["spring"], "Passing upwards through a spring must not activate it")
		game.player_pos = Vector2(170, 600)
		game.player_vel.y = 180
		game.check_player_block_collisions()
		assert(game.player_vel.y == 180 and spring_platform["spring"], "Missing the spring horizontally must not collect it")
		game.player_pos = Vector2(270, 590)
		game.player_vel.y = 180
		var position_before: Vector2 = game.player_pos
		game.paused = true
		game._process(1.0)
		assert(game.player_pos == position_before and spring_platform["spring"], "Pause must preserve the uncollected spring and jump state")
		game.paused = false
		game.tilt_control.blocking = true
		game._process(1.0)
		assert(game.player_pos == position_before and spring_platform["spring"], "Sensor permission must not collect the spring")
		game.tilt_control.blocking = false
		for frame in frames_per_second:
			game._process(1.0 / frames_per_second)
			if not spring_platform["spring"]:
				break
		assert(not spring_platform["spring"], "Landing must consume the spring immediately")
		assert(game.player_vel.y < -1000 and game.health == 3, "Spring contact must launch the hero immediately without damage")
		var takeoff_y: float = game.player_pos.y
		var height_before: float = game.height_meters
		var launch_velocity: Vector2 = game.player_vel
		game.paused = true
		game._process(1.0)
		assert(game.player_vel == launch_velocity and is_equal_approx(game.player_pos.y, takeoff_y), "Pause must freeze the actual spring jump")
		game.paused = false
		game.blocks.clear()
		for frame in frames_per_second * 2:
			game._process(1.0 / frames_per_second)
			if game.player_vel.y >= 0.0:
				break
		var rise: float = takeoff_y - game.player_pos.y + (game.height_meters - height_before) / 0.19
		assert(rise > 700 and rise < 750, "A spring jump must actually rise about twice the normal 370 pixels at every frame rate")
		game.blocks = [spring_platform]
		game.player_pos = Vector2(270, spring_platform["pos"].y - 50)
		game.player_vel = Vector2(0, 180)
		game.check_player_block_collisions()
		assert(game.blocks.is_empty() and is_equal_approx(game.player_vel.y, -game.PLATFORM_BOUNCE_SPEED), "Landing again on the consumed spring's stone platform must give only a normal bounce")
		game.blocks = [_spring_test_platform(false)]
		game.player_pos = Vector2(270, 650)
		game.player_vel = Vector2(0, 180)
		game.check_player_block_collisions()
		assert(is_equal_approx(game.player_vel.y, -game.PLATFORM_BOUNCE_SPEED), "Every subsequent ordinary platform must give a normal jump")
		game.blocks = [_spring_test_platform()]
		game.player_pos = Vector2(270, 600)
		game.player_vel.y = 180
		game.check_player_block_collisions()
		assert(is_equal_approx(game.player_vel.y, -game.SPRING_BOUNCE_SPEED) and not game.blocks[0]["spring"], "A fresh spring must give another single high jump without stacking strength")
		game.blocks = [_spring_test_platform(false)]
		game.player_pos = Vector2(270, 650)
		game.player_vel = Vector2(0, 180)
		game.update_game(0.02)
		assert(is_equal_approx(game.player_vel.y, -game.PLATFORM_BOUNCE_SPEED), "Even immediately after a spring, an ordinary platform must give the normal jump")
	game.start_game()
	assert(game.blocks[2]["spring"], "Restart must restore the opening spring")
	print("SPRING_TEST_OK single_use double_height normal_followup consumed_platform pause fresh_spring restart fps_30_60_120")


func _test_spring_rarity(game) -> void:
	var previous_count := 1000
	for scenario in [[0, 5, 7], [500, 7, 9], [1000, 9, 11], [3000, 17, 19]]:
		game.start_game()
		game.rng.seed = 529
		game.height_meters = scenario[0]
		game.platforms_until_spring = 0
		var count := 0
		var last_row := -1
		for row in 240:
			game.blocks.clear()
			game.ghosts.clear()
			game.spawn_block(-100)
			if game.blocks.back()["spring"]:
				assert(game.ghosts.is_empty() and game.blocks.size() == 1, "Rarer spring rows must remain free of ghosts and decoys")
				if last_row >= 0:
					assert(row - last_row >= scenario[1] and row - last_row <= scenario[2], "Spring gaps must grow with the run's height")
				last_row = row
				count += 1
		assert(count > 0 and count < previous_count, "Higher sections must have fewer springs without removing them entirely")
		previous_count = count
	game.start_game()
	assert(game.height_meters == 0 and game.blocks[2]["spring"] and game.platforms_until_spring <= 6, "Restart must reset spring rarity for the new run")
	print("SPRING_RARITY_TEST_OK heights_0_500_1000_3000 fewer_pickups safe_rows reset")


func _test_fast_ghost_death(game) -> void:
	game.start_game()
	game.spawn_ghost_pop(Vector2(270, 450))
	game.update_ghost_deaths(0.9)
	assert(game.ghost_deaths.size() == 1 and is_equal_approx(game.ghost_deaths[0]["time"], 1.8), "Ghost dispersal must play twice as fast, keeping the end of the clip")
	game.update_ghost_deaths(0.03)
	assert(game.ghost_deaths.is_empty(), "The full ghost death must finish in about 0.92 seconds")
	print("GHOST_DEATH_TEST_OK double_speed full_clip under_one_second")


func _test_rockets_ignore_platforms(game) -> void:
	for frames_per_second in [30, 60, 120]:
		for direction in [-1.0, 1.0]:
			game.start_game()
			game.ghosts.clear()
			game.blocks = [
				{"pos": Vector2(200, 390), "size": Vector2(140, 60), "skin": 0, "kind": 0, "hp": 1, "max_hp": 1, "spring": true},
				{"pos": Vector2(200, 480), "size": Vector2(140, 60), "skin": 5, "kind": 1, "hp": 2, "max_hp": 2, "spring": true},
				{"pos": Vector2(200, 570), "size": Vector2(140, 60), "skin": 4, "kind": 2, "hp": 1, "max_hp": 1, "spring": true}
			]
			var platforms_before: Array = game.blocks.duplicate(true)
			var smashed_before: int = game.smashed_total
			var origin := Vector2(270, 700 if direction < 0 else 300)
			var shot := {"pos": origin, "vel": Vector2(0, direction * 690), "life": 2.2, "trail": 0.0}
			game.rockets = [shot.duplicate()]
			for frame in frames_per_second:
				game.update_rockets(1.0 / frames_per_second)
			assert(game.rockets.size() == 1, "Rockets must fly through every platform and spring without exploding")
			assert(game.blocks == platforms_before and game.smashed_total == smashed_before, "Shooting through platforms must not damage, crack or remove them")
			game.update_rockets(1.3)
			assert(game.rockets.is_empty(), "Missed shots must still expire normally")
			var target := Vector2(270, 420 if direction < 0 else 600)
			game.ghosts = [game.make_ghost(target, 0), game.make_ghost(Vector2(450, 300), 0)]
			game.ghost_deaths.clear()
			game.rockets = [shot.duplicate()]
			for frame in frames_per_second:
				game.update_rockets(1.0 / frames_per_second)
				if game.rockets.is_empty():
					break
			assert(game.rockets.is_empty() and game.ghosts.size() == 1 and game.ghost_deaths.size() == 1, "A rocket must pass through intervening platforms and kill the ghost beyond them")
			assert(game.ghosts[0]["pos"] == Vector2(450, 300), "Distant ghosts must survive the impact")
			assert(game.blocks == platforms_before and game.smashed_total == smashed_before, "An explosion inside a platform must leave all blocks and springs intact")
			assert(game.health == 3, "Rockets must not damage the hero")
	print("ROCKET_TARGETS_TEST_OK pass_through_all_blocks springs_safe ghosts_hit blast_safe expiry fps_30_60_120")


func _test_shots_preserve_motion(game) -> void:
	var control = load("res://scenes/main.tscn").instantiate()
	control.profile_path = "user://weapon_motion_control.cfg"
	root.add_child(control)
	_use_tilt_stub(control)
	control.leaderboard.api_url = ""
	for velocity in [Vector2.ZERO, Vector2(120, 650), Vector2(-170, -400)]:
		for aim_offset in [Vector2(0, -240), Vector2(-200, 0), Vector2(200, 0), Vector2(140, -220), Vector2(0, 240)]:
			for world in [game, control]:
				world.start_game()
				world.tutorial_visible = false
				world.blocks.clear()
				world.ghosts.clear()
				world.spawn_cursor_y = -100000.0
				world.player_pos = Vector2(270, 650)
				world.player_vel = velocity
			var target: Vector2 = game.player_pos + aim_offset
			var expected_direction := Vector2.DOWN
			game.handle_game_press(target)
			assert(game.player_vel == velocity and game.player_pos == control.player_pos, "Shots in every direction must preserve position and velocity")
			assert(game.rockets.size() == 1 and game.rockets[0]["vel"].normalized().dot(expected_direction) > 0.99, "With no ghosts, tapping anywhere must fire downward")
			var velocity_after_shot: Vector2 = game.player_vel
			game.launch_player(target)
			assert(game.player_vel == velocity_after_shot and game.rockets.size() == 1, "Reload must prevent extra rockets without changing movement")
			for frame in 18:
				game._process(1.0 / 60.0)
				control._process(1.0 / 60.0)
			assert(game.player_pos.is_equal_approx(control.player_pos) and game.player_vel.is_equal_approx(control.player_vel), "Firing and not firing must produce the same trajectory")
	control.free()
	print("WEAPON_MOTION_TEST_OK no_impulse all_directions falling rising trajectory reload")

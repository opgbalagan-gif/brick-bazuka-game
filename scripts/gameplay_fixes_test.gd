extends SceneTree

func _init() -> void:
	run.call_deferred()

func reset(game) -> void:
	game.start_game()
	game.tutorial_visible = false
	game.ghosts.clear()
	game.blocks.clear()
	game.spawn_cursor_y = -100000
	game.ghost_attack_timer = 1000

func platform(position: Vector2, fake: bool = false) -> Dictionary:
	return {"pos": position, "size": Vector2(140, 48), "skin": 5, "kind": 1, "hp": 2, "max_hp": 2, "fake": fake, "spring": false, "boots": false}

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://gameplay_fixes_test.cfg"
	root.add_child(game)
	game.leaderboard.api_url = ""
	game.set_process(false)
	test_respawn(game)
	test_sturdy_start(game)
	test_facing(game)
	test_attacks(game)
	test_wider_view(game)
	test_boots(game)
	await test_name_input(game)
	print("GAMEPLAY_FIXES_TEST_OK nearest_respawn sturdy_start movement_facing slower_attacks wider_view jet_boots masks name_input")
	game.free()
	quit()

func test_respawn(game) -> void:
	reset(game)
	var near := platform(Vector2(210, 820))
	near.merge({"motion_center": 210.0, "motion_amplitude": 60.0, "motion_phase": 0.0, "motion_rate": 0.8})
	var higher := platform(Vector2(220, 500))
	var decoy := platform(Vector2(210, 900), true)
	game.blocks = [higher, near, decoy]
	game.height_meters = 753
	game.player_pos = Vector2(270, game.WORLD_SIZE.y + 81)
	game.player_vel = Vector2(0, 200)
	game.update_game(1.0 / 60)
	assert(game.health == 2 and game.respawn_platform == near, "Falling must spend one life and choose the nearest safe visible board")
	assert(game.player_pos == near["pos"] + Vector2(70, -48) and game.player_vel == Vector2.ZERO, "Respawn must place the hero on the board")
	var hp: int = near["hp"]
	game.update_game(0.3)
	assert(game.player_pos == near["pos"] + Vector2(70, -48), "The respawn must follow its moving board")
	assert(game.height_meters == 753 and game.health == 2 and near["hp"] == hp, "Respawning must preserve score and board durability")
	game.paused = true
	var timer: float = game.respawn_timer
	game._process(0.2)
	assert(game.respawn_timer == timer, "Pause must freeze the platform respawn")
	game.paused = false
	game.update_game(0.31)
	assert(game.respawn_timer == 0 and game.player_vel.y < 0, "The hero must automatically resume jumping after the short landing")
	reset(game)
	game.blocks = [decoy]
	game.player_pos = Vector2(game.WORLD_SIZE.x - 5, game.WORLD_SIZE.y + 82)
	game.update_game(0.01)
	assert(not game.respawn_platform.get("fake", false) and game.blocks.has(game.respawn_platform), "If all boards are gone, respawn must supply a safe board")
	assert(game.respawn_platform["pos"].x + game.respawn_platform["size"].x <= game.WORLD_SIZE.x - 22, "A recovery board must fit the screen")
	game.respawn_timer = 0
	game.health = 1
	game.player_pos.y = game.WORLD_SIZE.y + 82
	game.update_game(0.01)
	assert(game.health == 0 and game.screen == game.Screen.GAME_OVER, "The last life must end the run without respawning")

func test_sturdy_start(game) -> void:
	game.start_game()
	for block in game.blocks:
		assert(block["hp"] >= 2 and not block["fake"], "All opening boards must survive the first landing")
	var counts: Array = []
	for altitude in [0, 2000]:
		game.rng.seed = 717
		game.height_meters = altitude
		var sturdy := 0
		for row in 240:
			game.blocks.clear()
			game.spawn_block(-500)
			sturdy += 1 if game.blocks.back()["hp"] > 1 else 0
		counts.append(sturdy)
	assert(counts[0] > 180 and counts[0] > counts[1] * 2, "Early sections must contain substantially fewer one-hit boards")

func test_facing(game) -> void:
	reset(game)
	for direction in [-1, 1]:
		game.player_vel = Vector2(direction * 220, -500)
		game.update_visual_controller(0.3)
		assert(game.facing_left == (direction < 0), "Facing must follow horizontal flight")
		game.ghosts = [game.make_ghost(game.player_pos + Vector2(-direction * 150, -200), 0)]
		game.reload_timer = 0
		game.launch_player()
		assert(game.facing_left == (direction < 0), "Shooting behind the hero must not reverse the body")
		game.player_vel.x = 0
		game.update_visual_controller(0.2)
		assert(game.facing_left == (direction < 0), "Vertical flight must retain the last facing without flicker")

func test_attacks(game) -> void:
	for fps in [15, 30, 60, 120]:
		reset(game)
		game.player_pos = Vector2(270, 460)
		game.previous_player_pos = game.player_pos
		game.player_vel = Vector2.ZERO
		game.ghost_attack_timer = 0
		game.update_ghost_attacks(0.01)
		assert(game.ghosts.size() == 1 and game.ghosts[0]["pos"].y > game.player_pos.y + 200, "Attackers must appear below the hero with some reaction distance")
		var elapsed := 0.0
		for frame in fps * 2:
			game.update_ghosts(1.0 / fps)
			elapsed += 1.0 / fps
			assert(game.ghosts[0]["vel"].length() <= 320.01, "Attack speed must stay below the new slower limit")
			game.check_player_ghost_collisions()
			if game.health == 2:
				break
		assert(elapsed >= 0.9 and game.health == 2 and game.ghosts.is_empty(), "The slower attack must allow reaction time and still spend only one life")
	reset(game)
	game.ghost_attack_timer = 0
	game.update_ghost_attacks(0.01)
	var snapshot: Array = game.ghosts.duplicate(true)
	game.paused = true
	game._process(1.0)
	assert(game.ghosts == snapshot, "Pause must freeze attack windup and flight")
	game.paused = false
	game.update_ghosts(5.0)
	assert(game.ghosts.is_empty(), "Missed attackers must expire")
	for spawn in 10:
		game.ghost_attack_timer = 0
		game.update_ghost_attacks(0.01)
	assert(game.ghosts.size() == 3, "An attack wave must not accumulate more than three ghosts")

func test_wider_view(game) -> void:
	reset(game)
	# These coordinates were outside the old view, but now belong to the playable screen.
	var lower_board := platform(Vector2(520, 1100))
	game.blocks = [lower_board]
	game.player_pos = Vector2(590, 1000)
	game.previous_player_pos = game.player_pos
	game.player_vel = Vector2.ZERO
	var visible_ghost: Dictionary = game.make_ghost(Vector2(620, 1140), 0)
	game.ghosts = [visible_ghost]
	game.cleanup_world()
	assert(game.blocks.has(lower_board) and game.ghosts.has(visible_ghost), "Visible objects in the expanded lower area must not be cleaned up")
	game.launch_player()
	assert(game.rockets[0]["target"] == visible_ghost, "Homing must include the expanded right and lower screen areas")
	for frame in 30:
		game.update_rockets(1.0 / 60)
		if not game.ghosts.has(visible_ghost):
			break
	assert(not game.ghosts.has(visible_ghost), "Rockets must reach targets beyond the old screen limits")
	game.player_pos = Vector2(590, game.WORLD_SIZE.y + 81)
	game.update_game(0.01)
	assert(game.health == 2 and game.respawn_platform == lower_board, "A fall must recover onto a board visible in the expanded lower area")
	var feet_on_screen: Vector2 = game.world_draw_transform() * (game.player_pos + Vector2(0, 48))
	var board_on_screen: Vector2 = game.platform_layer.transform * (lower_board["pos"] + Vector2(70, 0))
	assert(feet_on_screen.distance_to(board_on_screen) < 0.01, "Rendered feet must meet the platform after a scaled respawn")
	reset(game)
	game.player_pos = Vector2(400, game.CAMERA_TOP - 10)
	game.player_vel = Vector2.ZERO
	game.update_game(0.01)
	assert(is_equal_approx((game.world_draw_transform() * game.player_pos).y, 345.0), "Scrolling must keep the hero at the same readable screen height")
	assert(game.height_meters > 0, "Zooming out must preserve height scoring")


func test_boots(game) -> void:
	for fps in [30, 60, 120]:
		reset(game)
		var board := platform(Vector2(200, 700))
		board["boots"] = true
		game.blocks = [board]
		game.player_pos = Vector2(270, 610)
		game.player_vel = Vector2.ZERO
		game.check_boots_pickups()
		assert(not board["boots"] and game.jet_timer == game.JET_DURATION and game.player_vel.y == -game.JET_SPEED, "Boots must be consumed and launch immediately")
		game.blocks.clear()
		game.previous_player_pos = game.player_pos
		game.ghosts = [game.make_ghost(game.player_pos, 0), game.make_ghost(game.player_pos + Vector2(10, -20), 0)]
		game.contact_cooldown = 1
		game.check_player_ghost_collisions()
		assert(game.health == 3 and game.ghosts.is_empty() and game.ghost_deaths.size() == 2, "Jet contact must defeat ghosts without losing a life, even during protection")
		var timer: float = game.jet_timer
		game.paused = true
		game._process(1)
		assert(game.jet_timer == timer, "Pause must preserve jet fuel")
		game.paused = false
		var start_y: float = game.player_pos.y
		for frame in int(ceil(game.JET_DURATION * fps)) + 1:
			game.update_game(1.0 / fps)
		var rise: float = start_y - game.player_pos.y + game.height_meters / 0.19
		assert(rise > 2200 and rise < 2400 and game.jet_timer == 0, "Boots must carry the hero high and then run out at every frame rate")
		var velocity: float = game.player_vel.y
		game.update_game(0.1)
		assert(game.player_vel.y > velocity and game.contact_cooldown > 0, "Gravity must resume with brief protection at the end")
	game.start_game()
	assert(game.jet_timer == 0 and game.mask_polygon.size() > 10, "Restart must clear flight and initialize masks from the hero artwork")
	game.player_pos = Vector2(270, 400)
	game.previous_player_pos = Vector2(270, 650)
	game.jet_timer = 1.0
	var crossing: Dictionary = game.make_ghost(Vector2(270, 600), 0)
	crossing["previous_pos"] = Vector2(270, 440)
	game.ghosts = [crossing]
	game.check_player_ghost_collisions()
	assert(game.ghosts.is_empty() and game.health == 3, "Fast opposing flight paths must collide even between rendered frames")
	var pickups := 0
	for row in 60:
		game.blocks.clear()
		game.spawn_block(-500)
		var safe: Dictionary = game.blocks.back()
		if safe.get("boots", false):
			pickups += 1
			assert(not safe["spring"] and game.blocks.size() == 1, "Boots must have clear, safe pickup platforms")
	assert(pickups >= 3, "Boots must recur in longer runs")

func test_name_input(game) -> void:
	game.leaderboard.start_run()
	game.leaderboard.show_results(123)
	await process_frame
	await process_frame
	assert(game.leaderboard.name_input.editable and game.leaderboard.name_input.has_focus(), "Native results must focus an editable name field even while offline")
	game.leaderboard.name_input.insert_text_at_caret("Игрок 42")
	assert(game.leaderboard.name_input.text.ends_with("Игрок 42"), "Cyrillic input must be accepted")
	game.leaderboard._response(0, 200, PackedStringArray(), "<html>Temporary upstream error</html>".to_utf8_buffer(), "runs")
	assert(game.leaderboard.name_input.editable and not game.leaderboard.busy["runs"], "An unexpected server page must leave the name editable and allow retry")
	game.leaderboard.dismiss()
	assert(not game.leaderboard.visible and not game.leaderboard.name_input.has_focus(), "Leaving results must release text input")

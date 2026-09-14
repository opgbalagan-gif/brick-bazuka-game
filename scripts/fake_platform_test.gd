extends SceneTree


func _init() -> void:
	run.call_deferred()


func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://fake_platform_test.cfg"
	root.add_child(game)
	game.leaderboard.api_url = ""
	game.set_process(false)
	test_generation(game)
	test_contacts(game)
	test_rockets(game)
	print("FAKE_PLATFORM_TEST_OK smaller safe_route recurring_decoys bounds gap falling_rubble no_bounce rockets_ignore fps_30_60_120")
	game.free()
	quit()


func test_generation(game) -> void:
	var fake_count := 0
	for seed_value in [17, 483, 9001]:
		game.rng.seed = seed_value
		game.start_game()
		assert(game.blocks.size() == 4, "The opening must contain four reliable platforms")
		for block in game.blocks:
			assert(not block["fake"], "Opening platforms must not crumble without a bounce")
		game.blocks.clear()
		var pairs: Array = []
		for row in 80:
			var before: int = game.blocks.size()
			game.spawn_block(-row * 280.0)
			var row_blocks: Array = game.blocks.slice(before)
			var safe: Array = row_blocks.filter(func(block): return not block["fake"])
			var decoys: Array = row_blocks.filter(func(block): return block["fake"])
			assert(safe.size() == 1 and decoys.size() <= 1, "Every row needs exactly one safe platform")
			assert(safe[0]["size"].x >= 110 and safe[0]["size"].x <= 160, "Safe platforms must use the smaller scale")
			for block in row_blocks:
				var source: Rect2 = game.PLATFORM_ART[block["skin"]]["region"]
				assert(absf(block["size"].aspect() - source.size.aspect()) < 0.01, "Smaller artwork must retain its proportions")
			if not decoys.is_empty():
				fake_count += 1
				assert(not decoys[0]["spring"] and not safe[0]["spring"], "Spring rows must stay clear of decoys")
				pairs.append([safe[0], decoys[0]])
		assert(pairs.size() >= 15 and pairs.size() <= 28, "Long runs must have recurring but occasional decoys")
		var initial_blocks: Array = game.blocks.duplicate(true)
		game.tutorial_visible = false
		game.paused = true
		game._process(0.3)
		assert(game.blocks == initial_blocks, "Pause must freeze safe and fake platforms together")
		game.paused = false
		for frame in 900:
			game.update_platforms(1.0 / 30.0)
			for block in game.blocks:
				assert(block["pos"].x >= 21.99 and block["pos"].x + block["size"].x <= 518.01, "Both ends of every platform must remain on screen")
			for pair in pairs:
				var left: Dictionary = pair[0] if pair[0]["pos"].x < pair[1]["pos"].x else pair[1]
				var right: Dictionary = pair[1] if pair[0]["pos"].x < pair[1]["pos"].x else pair[0]
				assert(absf(right["pos"].x - left["pos"].x - left["size"].x - 48.0) < 0.01, "The safe route and decoy must never overlap as they move")
	assert(fake_count > 45, "All tested worlds must include decoys")


func fake_block(position: Vector2) -> Dictionary:
	return {"pos": position, "size": Vector2(100, 40), "skin": 7, "kind": 1, "hp": 1, "max_hp": 1, "spring": false, "fake": true}


func test_contacts(game) -> void:
	for frames_per_second in [30, 60, 120]:
		for after_spring in [false, true]:
			game.start_game()
			game.tutorial_visible = false
			game.ghosts.clear()
			game.spawn_cursor_y = -100000.0
			if after_spring:
				var spring := fake_block(Vector2(220, 700))
				spring["fake"] = false
				spring["spring"] = true
				game.blocks = [spring]
				game.player_pos = Vector2(270, 600)
				game.player_vel = Vector2(0, 180)
				game.check_player_block_collisions()
				assert(game.player_vel.y < -1000, "Set up a real spring jump before returning to the decoy")
			game.particles.clear()
			var decoy := fake_block(Vector2(220, 700))
			var safe := {"pos": Vector2(205, 820), "size": Vector2(130, 44), "skin": 5, "kind": 1, "hp": 2, "max_hp": 2, "spring": false}
			game.blocks = [safe, decoy]
			game.player_pos = Vector2(270, 650)
			game.player_vel = Vector2(35, -180)
			game.check_player_block_collisions()
			assert(game.blocks.has(decoy), "Passing upward through a decoy must not break it")
			game.player_vel = Vector2(35, 180)
			var position_before: Vector2 = game.player_pos
			var velocity_before: Vector2 = game.player_vel
			var smashed_before: int = game.smashed_total
			game.check_player_block_collisions()
			assert(not game.blocks.has(decoy) and game.blocks.has(safe), "The decoy must disappear on first downward contact")
			assert(game.player_pos == position_before and game.player_vel == velocity_before, "Crumbling must not snap the player or give any bounce")
			assert(game.health == 3 and game.smashed_total == smashed_before + 1, "A collapse must count once and cause no direct life loss")
			assert(not game.particles.is_empty(), "Collapse must immediately produce visible rubble")
			for particle in game.particles:
				assert(particle["vel"].y > 0 and particle["gravity"] > 0, "Crumbling rubble must fall downward")
			game.check_player_block_collisions()
			assert(game.smashed_total == smashed_before + 1, "A vanished decoy must not crumble twice")
			for frame in frames_per_second:
				game.update_game(1.0 / frames_per_second)
				if safe["hp"] == 1:
					break
			assert(safe["hp"] == 1 and game.player_vel.y < 0 and game.health == 3, "The hero must fall through a decoy and still land on a lower safe platform")
			assert(is_equal_approx(game.player_vel.y, -game.PLATFORM_BOUNCE_SPEED), "The safe landing after a decoy must give a normal jump, even following a spring")
	game.particles.clear()
	game.spawn_fake_crumble(Rect2(200, 400, 100, 40))
	game.update_particles(1.0)
	assert(game.particles.is_empty(), "Collapse effects must clean themselves up")


func test_rockets(game) -> void:
	game.start_game()
	game.ghosts.clear()
	var decoy := fake_block(Vector2(220, 500))
	game.blocks = [decoy]
	var original: Dictionary = decoy.duplicate(true)
	game.rockets = [{"pos": Vector2(270, 600), "vel": Vector2(0, -690), "life": 2.0, "trail": 0.0}]
	game.update_rockets(0.3)
	assert(game.blocks == [original] and game.rockets.size() == 1, "A rocket must pass through fake platforms too")
	game.ghosts = [game.make_ghost(Vector2(270, 520), 0)]
	game.rockets = [{"pos": Vector2(270, 600), "vel": Vector2(0, -690), "life": 2.0, "trail": 0.0}]
	game.update_rockets(0.15)
	assert(game.ghosts.is_empty() and game.blocks == [original], "Exploding on a ghost must leave the nearby decoy intact")

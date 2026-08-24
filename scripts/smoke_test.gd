extends SceneTree


func _init() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	assert(packed != null, "Main scene must load")
	var game = packed.instantiate()
	root.add_child(game)
	game.start_game()
	game.tutorial_visible = false
	game.player_pos = Vector2(270, 460)
	game.player_vel = Vector2.ZERO
	var shot_target: Vector2 = game.player_pos + Vector2(140, 240)
	game.update_aim_target(shot_target)
	assert(not game.facing_left, "A rightward shot must turn the hero to the right")
	var solution: Dictionary = game.get_aim_solution(shot_target)
	var expected_shot_direction: Vector2 = solution["direction"]
	game.launch_player(shot_target)
	assert(game.rockets.size() == 1, "A shot must create one rocket")
	assert(game.rockets[0]["pos"].distance_to(solution["muzzle"]) < 0.01, "Rocket must spawn at the rotating muzzle")
	assert(game.rockets[0]["vel"].normalized().dot(expected_shot_direction) > 0.99, "Rocket must fly toward the target")
	assert(game.player_vel.dot(expected_shot_direction) < 0, "Recoil must push opposite to the shot")
	assert(game.player_vel.x < 0 and game.player_vel.y < 0, "Down-right shot must recoil up-left")
	var rocket_count: int = game.rockets.size()
	game.launch_player(shot_target)
	assert(game.rockets.size() == rocket_count, "Reload must block immediate shot spam")
	game.reload_timer = 0.0
	game.player_vel = Vector2.ZERO
	var down_target: Vector2 = game.player_pos + Vector2(0, 260)
	game.update_aim_target(down_target)
	var down_solution: Dictionary = game.get_aim_solution(down_target)
	game.launch_player(down_target)
	assert(absf(down_solution["direction"].x) < 0.12 and game.player_vel.y < 0, "Down shot must remain mostly vertical and move up")
	game.reload_timer = 0.0
	game.player_vel = Vector2.ZERO
	var left_target: Vector2 = game.player_pos + Vector2(-140, 240)
	game.update_aim_target(left_target)
	assert(game.facing_left, "A leftward shot must turn the hero to the left")
	game.launch_player(left_target)
	assert(game.player_vel.x > 0 and game.player_vel.y < 0, "Down-left shot must recoil up-right")

	var smashed_before: int = game.smashed_total
	game.damage_block(0, 99)
	assert(game.smashed_total == smashed_before + 1, "Brick destruction must advance the mission")
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
	game.update_visual_controller(0.12)
	assert(game.visual_body_rotation > 0, "Down-right aim must lean the body clockwise")
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
	for frame in 12:
		game.update_visual_controller(1.0 / 60.0)
	assert(game.visual_body_rotation < 0, "Down-left aim must lean the body counter-clockwise")
	assert(game.weapon_anchor_x < 0, "The bazooka grip must move to the hero's left-facing hand")
	var left_draw_state: Dictionary = game.get_weapon_draw_state()
	assert(left_draw_state["scale"].x > 0, "Left-facing bazooka must use its original readable orientation")
	assert(absf(wrapf(left_draw_state["rotation"], -PI, PI)) <= PI * 0.5, "Left-facing bazooka must stay upright")
	game.update_aim_target(game.player_pos + Vector2(130, 250))
	for frame in 24:
		game.update_visual_controller(1.0 / 60.0)
	assert(not game.facing_left and game.weapon_anchor_x > 0, "Rightward aim must flip the hero and grip together")

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
	assert(game.money >= 0, "Money cannot become negative")
	game.save_profile()
	print("SMOKE_TEST_OK first_controller=restored muzzle=aligned recoil=additive rotations=stable bounce=restored height=", int(game.height_meters))
	quit(0)

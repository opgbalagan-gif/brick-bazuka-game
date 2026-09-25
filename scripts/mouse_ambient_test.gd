extends SceneTree

func _init() -> void:
	run.call_deferred()

func button(game, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	game._unhandled_input(event)

func move(game, point: Vector2, held: bool = true) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	game._unhandled_input(event)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://mouse_ambient_test.cfg"
	root.add_child(game)
	game.leaderboard.api_url = ""
	game.set_process(false)
	game.start_game()
	assert(game.ghosts.any(func(ghost): return ghost.get("ambient", false)), "Some ghosts must already be present on the opening route")
	var ambient_before: int = game.ghosts.size()
	game.ghost_attack_timer = 0
	game.update_ghost_attacks(0.01)
	assert(game.ghosts.size() == ambient_before + 1 and game.ghosts.back()["attack"], "Ambient ghosts must coexist with attacks from below")
	var drifting: Dictionary = game.ghosts[0]
	var origin: Vector2 = drifting["pos"]
	game.update_ghosts(0.5)
	assert(drifting["pos"].x != origin.x and absf(drifting["vx"]) <= 42, "Map ghosts must drift slowly rather than charge")
	game.ghosts.clear()
	game.blocks.clear()
	game.spawn_cursor_y = -100000
	game.ghost_attack_timer = 1000
	game.player_pos = Vector2(330, 700)
	game.player_vel = Vector2.ZERO
	button(game, Vector2(100, 500), true)
	for frame in 24:
		game._process(1.0 / 60)
	assert(game.player_vel.x < -250 and game.rockets.is_empty(), "Holding the left half with a mouse must move without shooting")
	move(game, Vector2(200, 500))
	game._process(0.4)
	assert(game.player_vel.x > 0, "Dragging right must reverse mouse steering")
	button(game, Vector2(200, 500), false)
	assert(game.rockets.is_empty() and not game.touch_control.is_steering(), "Releasing a mouse drag must not shoot")
	button(game, Vector2(300, 400), true)
	button(game, Vector2(300, 400), false)
	assert(game.rockets.size() == 1, "A short mouse click must fire")
	button(game, Vector2(100, 500), true)
	game._process(0.2)
	move(game, Vector2(100, 500), false)
	assert(not game.touch_control.is_steering(), "A lost mouse release must not leave steering stuck")
	var position: Vector2 = game.player_pos
	game.open_leaderboard()
	game._process(0.5)
	button(game, Vector2(100, 500), true)
	assert(game.paused and game.player_pos == position and not game.touch_control.is_steering(), "Opening the rating must pause gameplay and block mouse gestures")
	game.leaderboard.close_button.pressed.emit()
	assert(not game.paused and not game.leaderboard.visible, "Closing the rating must resume the same game")
	game.free()
	print("MOUSE_AMBIENT_TEST_OK hold drag reverse click lost_release board_pause ambient_ghosts attacks_coexist")
	quit()

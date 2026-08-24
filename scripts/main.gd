extends Node2D

enum Screen { MENU, GAME, GAME_OVER }

const VIEW_SIZE := Vector2(540.0, 960.0)
const SAVE_PATH := "user://brick_bazuka_save.cfg"
const INITIAL_BLOCK_ROWS := 7
const BLOCK_GAP_MIN := 135.0
const BLOCK_GAP_MAX := 185.0
const DOUBLE_BLOCK_CHANCE := 0.14

const HERO_TEX := preload("res://assets/characters/main_hero.png")
const HERO_BODY_TEX := preload("res://assets/characters/main_hero_body.png")
const PLAY_TEX := preload("res://assets/ui/play_icon.svg")
const SHIELD_TEX := preload("res://assets/ui/shield_icon.svg")
const MAGNET_TEX := preload("res://assets/ui/magnet_icon.svg")
const BOOTS_TEX := preload("res://assets/ui/boots_icon.svg")
const BAZOOKA_TEX := preload("res://assets/weapons/bazooka_reference.png")
const BAZOOKA_BODY_TEX := preload("res://assets/weapons/bazooka_body.png")
const ROCKET_TEX := preload("res://assets/weapons/rocket.svg")
const BRICK_TEX := preload("res://assets/blocks/brick_tile.svg")
const CASH_TEX := preload("res://assets/pickups/cash_bundle.svg")
const GEM_TEX := preload("res://assets/pickups/rare_gem.svg")
const EXPLOSION_TEX := preload("res://assets/effects/explosion.svg")
const CITY_TEX := preload("res://assets/backgrounds/city_silhouette.svg")

const INK := Color("071426")
const DEEP := Color("061b39")
const PANEL_BLUE := Color("082b4b")
const CYAN := Color("30d9ff")
const PALE_CYAN := Color("b8f7ff")
const ORANGE := Color("f06a28")
const GOLD := Color("ffd238")
const LIME := Color("78e43b")
const GREEN := Color("28b947")
const WHITE := Color("f5f8ee")
const RED := Color("ff493d")

var screen := Screen.MENU
var paused := false
var tutorial_visible := false
var settings_open := false
var menu_overlay := ""
var sound_enabled := true
var haptics_enabled := true
var menu_time := 0.0
var toast_text := ""
var toast_timer := 0.0

var money := 2400
var upgrades := {"boots": 1, "bazooka": 1, "magnet": 1, "shield": 1}
var mission_claimed := {"smash": false, "cash": false, "height": false}
var smashed_total := 0
var cash_total := 0
var best_meters := 0
var last_daily_date := ""

var rng := RandomNumberGenerator.new()
var player_pos := Vector2.ZERO
var player_vel := Vector2.ZERO
var height_meters := 0.0
var run_cash := 0
var shield_available := true
var shoot_timer := 0.0
var reload_timer := 0.0
var hit_timer := 0.0
var flame_timer := 0.0
var recoil_anim := 0.0
var camera_shake := 0.0
var screen_flash := 0.0
var last_shot_direction := Vector2.DOWN
var aim_direction := Vector2.DOWN
var last_aim_target := Vector2(270, 820)
var aiming := false
var visual_body_rotation := 0.0
var visual_weapon_rotation := PI * 0.5
var body_angular_kick := 0.0
var weapon_kick := 0.0
var facing_left := false
var weapon_anchor_x := 22.0
var current_shake_offset := Vector2.ZERO
var spawn_cursor_y := -100.0
var blocks: Array = []
var rockets: Array = []
var pickups: Array = []
var particles: Array = []

var settings_rect := Rect2(16, 18, 54, 54)
var money_rect := Rect2(358, 18, 166, 54)
var cta_rect := Rect2(146, 448, 248, 62)
var upgrade_rects: Array[Rect2] = []
var nav_rects: Array[Rect2] = []
var pause_rect := Rect2(474, 18, 50, 50)


func _ready() -> void:
	rng.randomize()
	load_profile()
	if OS.get_cmdline_user_args().has("--capture-game"):
		start_game()
		tutorial_visible = false
		launch_player(Vector2(360, 820))
	queue_redraw()


func _process(delta: float) -> void:
	menu_time += delta
	toast_timer = maxf(0.0, toast_timer - delta)
	shoot_timer = maxf(0.0, shoot_timer - delta)
	reload_timer = maxf(0.0, reload_timer - delta)
	hit_timer = maxf(0.0, hit_timer - delta)
	flame_timer = maxf(0.0, flame_timer - delta)
	recoil_anim = maxf(0.0, recoil_anim - delta)
	weapon_kick = maxf(0.0, weapon_kick - delta * 6.5)
	body_angular_kick *= exp(-9.0 * delta)
	camera_shake = maxf(0.0, camera_shake - delta * 3.8)
	screen_flash = maxf(0.0, screen_flash - delta * 4.5)
	if screen == Screen.GAME:
		update_visual_controller(delta)
	if screen == Screen.GAME and not paused and not tutorial_visible:
		update_game(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if screen == Screen.GAME:
			if event.pressed:
				begin_aim(event.position)
			else:
				end_aim(event.position)
		elif event.pressed:
			handle_press(event.position)
		return
	if event is InputEventScreenDrag and screen == Screen.GAME:
		update_aim_target(event.position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if screen == Screen.GAME:
			if event.pressed:
				begin_aim(event.position)
			else:
				end_aim(event.position)
		elif event.pressed:
			handle_press(event.position)
		return
	if event is InputEventMouseMotion and screen == Screen.GAME and aiming:
		update_aim_target(event.position)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			handle_press(player_pos + Vector2(0, 260) if screen == Screen.GAME else Vector2(270, 760))
		elif event.keycode == KEY_ESCAPE:
			if screen == Screen.GAME:
				aiming = false
				paused = not paused
			elif settings_open or menu_overlay != "":
				settings_open = false
				menu_overlay = ""


func begin_aim(position: Vector2) -> void:
	if paused:
		handle_game_press(position)
		return
	if pause_rect.has_point(position):
		paused = true
		aiming = false
		return
	if tutorial_visible:
		tutorial_visible = false
	aiming = true
	update_aim_target(position)


func end_aim(position: Vector2) -> void:
	if not aiming or paused:
		return
	update_aim_target(position)
	aiming = false
	launch_player(position)


func update_aim_target(position: Vector2) -> void:
	last_aim_target = Vector2(clampf(position.x, 12, 528), clampf(position.y, 100, 944))
	var solution := get_aim_solution(last_aim_target)
	aim_direction = solution["direction"]
	if aim_direction.x < 0.0:
		facing_left = true
	elif aim_direction.x > 0.0:
		facing_left = false


func update_visual_controller(delta: float) -> void:
	var desired_weapon_angle := aim_direction.angle()
	var weapon_weight := 1.0 - exp(-20.0 * delta)
	visual_weapon_rotation = lerp_angle(visual_weapon_rotation, desired_weapon_angle, weapon_weight)
	var lean_limit := deg_to_rad(50.0)
	var desired_body_rotation := clampf(aim_direction.x * deg_to_rad(42.0), -lean_limit, lean_limit)
	if not aiming and recoil_anim <= 0.0:
		desired_body_rotation = clampf(player_vel.x / 720.0 * deg_to_rad(24.0), -deg_to_rad(28.0), deg_to_rad(28.0))
	var body_weight := 1.0 - exp(-7.0 * delta)
	visual_body_rotation = lerp_angle(visual_body_rotation, desired_body_rotation, body_weight)
	var desired_anchor_x := -22.0 if facing_left else 22.0
	weapon_anchor_x = lerpf(weapon_anchor_x, desired_anchor_x, 1.0 - exp(-14.0 * delta))


func get_weapon_pivot() -> Vector2:
	var local_anchor := Vector2(weapon_anchor_x, -16)
	return player_pos + local_anchor.rotated(visual_body_rotation + body_angular_kick)


func get_weapon_draw_state() -> Dictionary:
	var points_left := cos(visual_weapon_rotation) < 0.0
	if points_left:
		return {"rotation": visual_weapon_rotation - PI, "scale": Vector2.ONE, "points_left": true}
	return {"rotation": visual_weapon_rotation, "scale": Vector2(-1.0, 1.0), "points_left": false}


func get_aim_solution(target: Vector2) -> Dictionary:
	var pivot := get_weapon_pivot()
	var direction := (target - pivot).normalized()
	if direction.length_squared() < 0.5:
		direction = Vector2.DOWN
	var muzzle := pivot + direction * 68.0
	return {"pivot": pivot, "direction": direction, "muzzle": muzzle}


func handle_press(position: Vector2) -> void:
	if screen == Screen.MENU:
		handle_menu_press(position)
	elif screen == Screen.GAME:
		handle_game_press(position)
	else:
		handle_game_over_press(position)


func handle_menu_press(position: Vector2) -> void:
	if settings_open:
		if Rect2(95, 368, 350, 64).has_point(position):
			sound_enabled = not sound_enabled
			show_toast("SOUND " + ("ON" if sound_enabled else "OFF"))
		elif Rect2(95, 448, 350, 64).has_point(position):
			haptics_enabled = not haptics_enabled
			show_toast("HAPTICS " + ("ON" if haptics_enabled else "OFF"))
		elif not Rect2(70, 260, 400, 340).has_point(position):
			settings_open = false
		save_profile()
		return
	if menu_overlay != "":
		if menu_overlay == "daily" and Rect2(145, 540, 250, 64).has_point(position):
			claim_daily_reward()
		elif Rect2(120, 635, 300, 58).has_point(position) or not Rect2(60, 220, 420, 500).has_point(position):
			menu_overlay = ""
		return
	if settings_rect.has_point(position):
		settings_open = true
		return
	if cta_rect.has_point(position) or Rect2(212, 866, 116, 86).has_point(position):
		start_game()
		return
	for index in upgrade_rects.size():
		if upgrade_rects[index].has_point(position):
			purchase_upgrade(index)
			return
	for index in nav_rects.size():
		if nav_rects[index].has_point(position):
			match index:
				0:
					menu_overlay = "shop"
				1:
					menu_overlay = "characters"
				2:
					start_game()
				3:
					menu_overlay = "leaderboard"
				4:
					menu_overlay = "daily"
			return


func handle_game_press(position: Vector2) -> void:
	if tutorial_visible:
		tutorial_visible = false
		launch_player(position)
		return
	if paused:
		if Rect2(120, 440, 300, 62).has_point(position):
			paused = false
		elif Rect2(120, 520, 300, 62).has_point(position):
			return_to_menu()
		return
	if pause_rect.has_point(position):
		paused = true
		return
	launch_player(position)


func handle_game_over_press(position: Vector2) -> void:
	if Rect2(92, 618, 356, 70).has_point(position):
		start_game()
	elif Rect2(92, 705, 356, 62).has_point(position):
		return_to_menu()


func start_game() -> void:
	screen = Screen.GAME
	paused = false
	settings_open = false
	menu_overlay = ""
	player_pos = Vector2(270, 665)
	player_vel = Vector2(0, -80)
	height_meters = 0.0
	run_cash = 0
	shield_available = true
	shoot_timer = 0.0
	reload_timer = 0.0
	hit_timer = 0.0
	recoil_anim = 0.0
	weapon_kick = 0.0
	body_angular_kick = 0.0
	camera_shake = 0.0
	screen_flash = 0.0
	last_shot_direction = Vector2.DOWN
	aim_direction = Vector2.DOWN
	aiming = false
	visual_body_rotation = 0.0
	visual_weapon_rotation = PI * 0.5
	facing_left = false
	weapon_anchor_x = 22.0
	last_aim_target = Vector2(270, 820)
	blocks.clear()
	rockets.clear()
	pickups.clear()
	particles.clear()
	spawn_cursor_y = 760.0
	for i in INITIAL_BLOCK_ROWS:
		spawn_block(spawn_cursor_y)
		spawn_cursor_y -= rng.randf_range(BLOCK_GAP_MIN, BLOCK_GAP_MAX)
	tutorial_visible = true


func return_to_menu() -> void:
	screen = Screen.MENU
	paused = false
	tutorial_visible = false
	save_profile()


func launch_player(target: Vector2) -> void:
	last_aim_target = target
	if reload_timer > 0.0:
		return
	var solution := get_aim_solution(target)
	var muzzle_position: Vector2 = solution["muzzle"]
	var shot_direction: Vector2 = solution["direction"]
	var recoil_direction := -shot_direction
	var boots_level: int = int(upgrades["boots"])
	var movement_impulse := 235.0 + float(boots_level - 1) * 11.0
	player_vel.y = maxf(player_vel.y - movement_impulse, -575.0)
	var assisted_x := clampf((target.x - player_pos.x) * 0.55, -130.0, 130.0)
	player_vel.x = lerpf(player_vel.x, assisted_x, 0.68)
	var bazooka_level: int = int(upgrades["bazooka"])
	var recoil_force := 420.0 + float(bazooka_level - 1) * 16.0
	player_vel += recoil_direction * recoil_force
	player_vel = player_vel.limit_length(730.0)
	last_shot_direction = shot_direction
	aim_direction = shot_direction
	if shot_direction.x < 0.0:
		facing_left = true
	elif shot_direction.x > 0.0:
		facing_left = false
	reload_timer = 0.56
	shoot_timer = 0.20
	recoil_anim = 0.20
	weapon_kick = 1.0
	body_angular_kick = -shot_direction.x * 0.20
	flame_timer = 0.22
	camera_shake = 0.72
	screen_flash = 0.26
	rockets.append({"pos": muzzle_position, "vel": shot_direction * 690.0, "life": 2.2, "trail": 0.0})
	spawn_muzzle(muzzle_position, shot_direction)


func update_game(delta: float) -> void:
	var gravity := 690.0
	player_vel.y += gravity * delta
	player_vel.x *= pow(0.18, delta)
	player_pos += player_vel * delta
	if player_pos.x < 48:
		player_pos.x = 48
		player_vel.x = absf(player_vel.x) * 0.55
	elif player_pos.x > 492:
		player_pos.x = 492
		player_vel.x = -absf(player_vel.x) * 0.55

	var camera_shift := 0.0
	if player_pos.y < 345:
		camera_shift = 345.0 - player_pos.y
		player_pos.y = 345.0
		height_meters += camera_shift * 0.19
		shift_world(camera_shift)

	spawn_world_if_needed()
	update_rockets(delta)
	update_pickups(delta)
	update_particles(delta)
	check_player_block_collisions()
	cleanup_world()

	if player_pos.y > 1040:
		if shield_available:
			shield_available = false
			player_pos.y = 770
			player_vel = Vector2(0, -270 - int(upgrades["shield"]) * 7)
			hit_timer = 0.45
			show_toast("SHIELD SAVE!")
		else:
			finish_run()


func shift_world(amount: float) -> void:
	for block in blocks:
		block["pos"] = block["pos"] + Vector2(0, amount)
	for rocket in rockets:
		rocket["pos"] = rocket["pos"] + Vector2(0, amount)
	for pickup in pickups:
		pickup["pos"] = pickup["pos"] + Vector2(0, amount)
	for particle in particles:
		particle["pos"] = particle["pos"] + Vector2(0, amount)
	spawn_cursor_y += amount


func spawn_world_if_needed() -> void:
	while spawn_cursor_y > -260:
		spawn_block(spawn_cursor_y)
		spawn_cursor_y -= rng.randf_range(BLOCK_GAP_MIN, BLOCK_GAP_MAX)


func spawn_block(y_position: float) -> void:
	var width := rng.randi_range(94, 158)
	var x := rng.randf_range(22.0, 518.0 - width)
	var roll := rng.randf()
	var kind := 0
	var hp := 1
	if roll > 0.82:
		kind = 3
		hp = 1
	elif roll > 0.64:
		kind = 2
		hp = 1
	elif roll > 0.48:
		kind = 1
		hp = 2
	blocks.append({"pos": Vector2(x, y_position), "size": Vector2(width, 52), "kind": kind, "hp": hp, "max_hp": hp})
	if rng.randf() < DOUBLE_BLOCK_CHANCE:
		var partner_width := rng.randi_range(68, 108)
		var partner_x := 0.0
		if x + width * 0.5 < 270:
			partner_x = minf(518.0 - partner_width, x + width + rng.randf_range(24, 58))
		else:
			partner_x = maxf(22.0, x - partner_width - rng.randf_range(24, 58))
		blocks.append({"pos": Vector2(partner_x, y_position + rng.randf_range(-14, 14)), "size": Vector2(partner_width, 48), "kind": 0, "hp": 1, "max_hp": 1})
	if rng.randf() < 0.32:
		pickups.append({"pos": Vector2(x + width * 0.5, y_position - 34), "vel": Vector2.ZERO, "rare": false, "value": 25})
	elif rng.randf() < 0.055:
		pickups.append({"pos": Vector2(x + width * 0.5, y_position - 36), "vel": Vector2.ZERO, "rare": true, "value": 150})


func update_rockets(delta: float) -> void:
	for index in range(rockets.size() - 1, -1, -1):
		var rocket = rockets[index]
		rocket["pos"] = rocket["pos"] + rocket["vel"] * delta
		rocket["life"] = float(rocket["life"]) - delta
		rocket["trail"] = float(rocket["trail"]) + delta
		if float(rocket["trail"]) >= 0.035:
			rocket["trail"] = 0.0
			var trail_direction: Vector2 = -rocket["vel"].normalized()
			var trail_velocity := trail_direction * rng.randf_range(18, 60) + Vector2(rng.randf_range(-25, 25), rng.randf_range(-25, 25))
			particles.append(make_particle(rocket["pos"] + trail_direction * 13, trail_velocity, Color("d7eef0"), rng.randf_range(4, 8), 0.42, -15))
		var hit_index := -1
		var rocket_rect := Rect2(rocket["pos"] - Vector2(12, 12), Vector2(24, 24))
		for block_index in range(blocks.size() - 1, -1, -1):
			var block = blocks[block_index]
			if rocket_rect.intersects(Rect2(block["pos"], block["size"])):
				hit_index = block_index
				break
		if hit_index >= 0:
			spawn_explosion(rocket["pos"])
			damage_explosion(rocket["pos"], hit_index)
			camera_shake = 1.0
			screen_flash = 0.38
			rockets.remove_at(index)
		elif float(rocket["life"]) <= 0.0 or rocket["pos"].y < -140 or rocket["pos"].y > 1100 or rocket["pos"].x < -120 or rocket["pos"].x > 660:
			rockets.remove_at(index)
		else:
			rockets[index] = rocket


func damage_explosion(position: Vector2, direct_index: int) -> void:
	var bazooka_level: int = int(upgrades["bazooka"])
	var radius := 60.0 + float(bazooka_level - 1) * 7.0
	var direct_damage := 1 + int((bazooka_level - 1) / 4)
	for index in range(blocks.size() - 1, -1, -1):
		var block = blocks[index]
		var center: Vector2 = block["pos"] + block["size"] * 0.5
		if index == direct_index:
			damage_block(index, direct_damage)
		elif center.distance_to(position) <= radius:
			damage_block(index, 1)


func damage_block(index: int, damage: int) -> void:
	if index < 0 or index >= blocks.size():
		return
	var block = blocks[index]
	block["hp"] = int(block["hp"]) - damage
	if int(block["hp"]) <= 0:
		var center: Vector2 = block["pos"] + block["size"] * 0.5
		var kind: int = int(block["kind"])
		blocks.remove_at(index)
		smashed_total += 1
		spawn_brick_burst(center, kind)
		if kind == 3:
			for i in 3:
				spawn_cash(center + Vector2(rng.randf_range(-30, 30), rng.randf_range(-14, 14)), 35)
		elif rng.randf() < 0.55:
			spawn_cash(center, 25)
		check_missions()
	else:
		blocks[index] = block
		spawn_hit_sparks(block["pos"] + block["size"] * 0.5)


func check_player_block_collisions() -> void:
	if player_vel.y <= 0:
		return
	var feet := Rect2(player_pos + Vector2(-35, 30), Vector2(70, 38))
	for index in range(blocks.size() - 1, -1, -1):
		var block = blocks[index]
		var block_rect := Rect2(block["pos"], block["size"])
		if feet.intersects(block_rect) and player_pos.y < block_rect.position.y + 16:
			player_pos.y = block_rect.position.y - 48
			player_vel.y = -355.0 - float(upgrades["boots"]) * 7.0
			hit_timer = 0.12
			damage_block(index, 1)
			return


func spawn_cash(position: Vector2, value: int) -> void:
	pickups.append({"pos": position, "vel": Vector2(rng.randf_range(-90, 90), rng.randf_range(-170, -80)), "rare": false, "value": value})


func update_pickups(delta: float) -> void:
	var magnet_radius := 70.0 + float(upgrades["magnet"]) * 18.0
	for index in range(pickups.size() - 1, -1, -1):
		var pickup = pickups[index]
		var direction: Vector2 = player_pos - pickup["pos"]
		var distance := direction.length()
		if distance < magnet_radius and distance > 1:
			pickup["vel"] = pickup["vel"] + direction.normalized() * (760.0 + float(upgrades["magnet"]) * 35.0) * delta
		pickup["vel"].y = float(pickup["vel"].y) + 165.0 * delta
		pickup["vel"] = pickup["vel"] * pow(0.45, delta)
		pickup["pos"] = pickup["pos"] + pickup["vel"] * delta
		if distance < 42:
			var value: int = int(pickup["value"])
			money += value
			run_cash += value
			cash_total += 1
			spawn_money_burst(player_pos, bool(pickup["rare"]))
			pickups.remove_at(index)
			check_missions()
		else:
			pickups[index] = pickup


func update_particles(delta: float) -> void:
	for index in range(particles.size() - 1, -1, -1):
		var particle = particles[index]
		particle["life"] = float(particle["life"]) - delta
		particle["vel"].y = float(particle["vel"].y) + float(particle["gravity"]) * delta
		particle["pos"] = particle["pos"] + particle["vel"] * delta
		particle["vel"] = particle["vel"] * pow(0.35, delta)
		if float(particle["life"]) <= 0:
			particles.remove_at(index)
		else:
			particles[index] = particle


func cleanup_world() -> void:
	for index in range(blocks.size() - 1, -1, -1):
		if blocks[index]["pos"].y > 1030:
			blocks.remove_at(index)
	for index in range(pickups.size() - 1, -1, -1):
		if pickups[index]["pos"].y > 1080:
			pickups.remove_at(index)


func finish_run() -> void:
	screen = Screen.GAME_OVER
	best_meters = maxi(best_meters, int(height_meters))
	check_missions()
	save_profile()


func spawn_muzzle(position: Vector2, direction: Vector2) -> void:
	var tangent := Vector2(-direction.y, direction.x)
	for i in 9:
		var velocity := direction * rng.randf_range(90, 230) + tangent * rng.randf_range(-85, 85)
		particles.append(make_particle(position, velocity, GOLD if i % 2 == 0 else ORANGE, rng.randf_range(4, 9), 0.32, 25))
	for i in 4:
		var smoke_velocity := -direction * rng.randf_range(18, 55) + tangent * rng.randf_range(-35, 35)
		particles.append(make_particle(position, smoke_velocity, Color("d8e4df"), rng.randf_range(6, 11), 0.48, -20))


func spawn_explosion(position: Vector2) -> void:
	for i in 18:
		var angle := rng.randf_range(0, TAU)
		var speed := rng.randf_range(80, 260)
		particles.append(make_particle(position, Vector2.from_angle(angle) * speed, GOLD if i % 3 == 0 else ORANGE, rng.randf_range(4, 11), rng.randf_range(0.35, 0.7), 230))


func spawn_brick_burst(position: Vector2, kind: int) -> void:
	var colors := [ORANGE, Color("a83b25"), Color("ff9a4b")]
	if kind == 1:
		colors = [Color("6a7480"), Color("b5c0c9"), Color("343b49")]
	for i in 15:
		particles.append(make_particle(position, Vector2(rng.randf_range(-230, 230), rng.randf_range(-260, -40)), colors[i % colors.size()], rng.randf_range(5, 12), rng.randf_range(0.55, 0.95), 540))


func spawn_hit_sparks(position: Vector2) -> void:
	for i in 7:
		particles.append(make_particle(position, Vector2(rng.randf_range(-150, 150), rng.randf_range(-170, 20)), WHITE if i % 2 == 0 else GOLD, rng.randf_range(3, 7), 0.35, 250))


func spawn_money_burst(position: Vector2, rare: bool) -> void:
	for i in 10:
		particles.append(make_particle(position, Vector2(rng.randf_range(-150, 150), rng.randf_range(-220, -20)), CYAN if rare and i % 2 == 0 else LIME, rng.randf_range(4, 9), 0.55, 300))


func make_particle(position: Vector2, velocity: Vector2, color: Color, size: float, life: float, gravity: float) -> Dictionary:
	return {"pos": position, "vel": velocity, "color": color, "size": size, "life": life, "max_life": life, "gravity": gravity}


func purchase_upgrade(index: int) -> void:
	var keys := ["boots", "bazooka", "magnet", "shield"]
	var key: String = keys[index]
	var price := upgrade_price(key)
	if money < price:
		show_toast("NOT ENOUGH CASH")
		return
	if int(upgrades[key]) >= 20:
		show_toast("MAX LEVEL")
		return
	money -= price
	upgrades[key] = int(upgrades[key]) + 1
	show_toast(key.to_upper() + "  LVL " + str(upgrades[key]))
	save_profile()


func upgrade_price(key: String) -> int:
	var bases := {"boots": 240, "bazooka": 180, "magnet": 160, "shield": 120}
	return int(bases[key]) * (int(upgrades[key]) + 1)


func check_missions() -> void:
	var changed := false
	if smashed_total >= 50 and not bool(mission_claimed["smash"]):
		mission_claimed["smash"] = true
		money += 1000
		show_toast("MISSION +1000")
		changed = true
	if cash_total >= 250 and not bool(mission_claimed["cash"]):
		mission_claimed["cash"] = true
		money += 1500
		show_toast("MISSION +1500")
		changed = true
	if best_meters >= 500 and not bool(mission_claimed["height"]):
		mission_claimed["height"] = true
		money += 1250
		show_toast("MISSION +1250")
		changed = true
	if changed:
		save_profile()


func claim_daily_reward() -> void:
	var today := Time.get_date_string_from_system()
	if last_daily_date == today:
		show_toast("ALREADY CLAIMED")
		return
	last_daily_date = today
	money += 500
	show_toast("DAILY REWARD +500")
	save_profile()


func show_toast(text: String) -> void:
	toast_text = text
	toast_timer = 2.0


func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	money = int(config.get_value("progress", "money", money))
	upgrades = config.get_value("progress", "upgrades", upgrades)
	mission_claimed = config.get_value("progress", "mission_claimed", mission_claimed)
	smashed_total = int(config.get_value("progress", "smashed_total", 0))
	cash_total = int(config.get_value("progress", "cash_total", 0))
	best_meters = int(config.get_value("progress", "best_meters", 0))
	last_daily_date = str(config.get_value("progress", "last_daily_date", ""))
	sound_enabled = bool(config.get_value("settings", "sound", true))
	haptics_enabled = bool(config.get_value("settings", "haptics", true))


func save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "money", money)
	config.set_value("progress", "upgrades", upgrades)
	config.set_value("progress", "mission_claimed", mission_claimed)
	config.set_value("progress", "smashed_total", smashed_total)
	config.set_value("progress", "cash_total", cash_total)
	config.set_value("progress", "best_meters", best_meters)
	config.set_value("progress", "last_daily_date", last_daily_date)
	config.set_value("settings", "sound", sound_enabled)
	config.set_value("settings", "haptics", haptics_enabled)
	config.save(SAVE_PATH)


func _exit_tree() -> void:
	save_profile()


func _draw() -> void:
	if screen == Screen.MENU:
		draw_menu()
	elif screen == Screen.GAME:
		draw_game()
	else:
		draw_game()
		draw_game_over()
	if toast_timer > 0:
		draw_toast()


func draw_menu() -> void:
	draw_sky(true)
	draw_menu_decorations()
	draw_top_bar()
	draw_logo()

	var hero_float := sin(menu_time * 2.2) * 7.0
	var hero_rect := Rect2(105, 222 + hero_float, 330, 280)
	draw_texture_rect(HERO_TEX, hero_rect, false)
	for i in 3:
		var flame_x := 224.0 + float(i) * 47.0
		draw_line(Vector2(flame_x, 477 + hero_float), Vector2(flame_x - 7, 505 + hero_float + sin(menu_time * 8 + i) * 5), GOLD, 5)

	draw_cta()
	draw_upgrade_cards()
	draw_missions()
	draw_navigation()
	if settings_open:
		draw_settings()
	elif menu_overlay != "":
		draw_menu_overlay()


func draw_sky(menu_mode: bool) -> void:
	for i in 24:
		var t := float(i) / 23.0
		var color := Color("064f9f").lerp(Color("18b9e9"), t)
		if not menu_mode:
			color = Color("032f73").lerp(Color("087fbd"), t)
		draw_rect(Rect2(0, i * 40, 540, 42), color)
	for i in 18:
		var x := fmod(float(i * 89 + 43), 540.0)
		var y := fmod(float(i * 151 + 80), 720.0)
		draw_rect(Rect2(x, y, 2, 8), Color(1, 1, 1, 0.22))
	draw_cloud(Vector2(55, 150), 0.72)
	draw_cloud(Vector2(442, 185), 0.92)
	draw_cloud(Vector2(110, 395), 0.48)
	draw_cloud(Vector2(420, 520), 0.55)
	draw_texture_rect(CITY_TEX, Rect2(0, 770, 540, 190), false, Color(1, 1, 1, 0.92))


func draw_cloud(position: Vector2, scale_value: float) -> void:
	var color := Color(0.91, 0.98, 1.0, 0.62)
	draw_circle(position, 30 * scale_value, color)
	draw_circle(position + Vector2(30, 7) * scale_value, 24 * scale_value, color)
	draw_circle(position + Vector2(-31, 10) * scale_value, 21 * scale_value, color)
	draw_rect(Rect2(position + Vector2(-47, 8) * scale_value, Vector2(92, 26) * scale_value), color)


func draw_menu_decorations() -> void:
	draw_brick(Rect2(12, 294, 106, 48), 2, 1, 1)
	draw_brick(Rect2(428, 318, 102, 47), 3, 1, 1)
	draw_brick(Rect2(40, 528, 92, 44), 0, 1, 1)
	draw_texture_rect(CASH_TEX, Rect2(444, 235, 66, 44), false)
	draw_texture_rect(CASH_TEX, Rect2(23, 220, 54, 36), false)
	draw_texture_rect(GEM_TEX, Rect2(462, 466, 42, 42), false)


func draw_top_bar() -> void:
	draw_panel(settings_rect, Color("08233e"), CYAN, 3, 10)
	for i in 8:
		var angle := float(i) * TAU / 8.0
		draw_rect(Rect2(settings_rect.get_center() + Vector2.from_angle(angle) * 15 - Vector2(3, 7), Vector2(6, 14)), WHITE)
	draw_circle(settings_rect.get_center(), 10, WHITE)
	draw_circle(settings_rect.get_center(), 4, PANEL_BLUE)
	draw_panel(money_rect, Color("061729"), PALE_CYAN, 3, 8)
	draw_coin(Vector2(384, 45), 18)
	draw_label(str(money), Vector2(406, 55), 25, WHITE, HORIZONTAL_ALIGNMENT_LEFT, 85)
	draw_panel(Rect2(483, 25, 34, 40), Color("38c43e"), Color("0b5b22"), 3, 7)
	draw_label("+", Vector2(485, 57), 33, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 31)


func draw_logo() -> void:
	draw_label("BRICK", Vector2(104, 136), 56, ORANGE, HORIZONTAL_ALIGNMENT_CENTER, 332, 5)
	draw_label("BAZUKA", Vector2(68, 193), 55, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 404, 5)
	draw_panel(Rect2(164, 198, 212, 36), Color("071a28"), INK, 2, 5)
	draw_label("CASH ASCENT", Vector2(164, 225), 24, LIME, HORIZONTAL_ALIGNMENT_CENTER, 212, 3)


func draw_cta() -> void:
	var pulse := 0.5 + 0.5 * sin(menu_time * 4.0)
	draw_panel(cta_rect, Color(0.01, 0.09, 0.16, 0.90), CYAN.lerp(WHITE, pulse * 0.45), 4, 12)
	draw_label("TAP TO FLY", Vector2(cta_rect.position.x, cta_rect.position.y + 43), 33, WHITE, HORIZONTAL_ALIGNMENT_CENTER, cta_rect.size.x, 4)
	draw_texture_rect(PLAY_TEX, Rect2(cta_rect.position.x + 14, cta_rect.position.y + 13, 38, 38), false)


func draw_upgrade_cards() -> void:
	upgrade_rects.clear()
	var keys := ["boots", "bazooka", "magnet", "shield"]
	var titles := ["JET BOOTS", "BAZOOKA", "CASH MAGNET", "SHIELD"]
	var icons := [BOOTS_TEX, BAZOOKA_TEX, MAGNET_TEX, SHIELD_TEX]
	for i in 4:
		var rect := Rect2(8 + i * 133, 521, 126, 164)
		upgrade_rects.append(rect)
		draw_panel(rect, Color("071f38"), CYAN, 3, 9)
		draw_label(titles[i], Vector2(rect.position.x + 2, rect.position.y + 23), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 4, 2)
		var icon_rect := Rect2(rect.position.x + 33, rect.position.y + 33, 60, 58)
		if i == 1:
			icon_rect = Rect2(rect.position.x + 17, rect.position.y + 40, 92, 52)
		draw_texture_rect(icons[i], icon_rect, false)
		draw_label("LVL " + str(upgrades[keys[i]]), Vector2(rect.position.x, rect.position.y + 111), 16, WHITE, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)
		var price_rect := Rect2(rect.position.x + 8, rect.position.y + 122, rect.size.x - 16, 34)
		draw_panel(price_rect, Color("27b73f"), Color("0b6829"), 2, 5)
		draw_coin(price_rect.position + Vector2(16, 17), 10)
		draw_label(str(upgrade_price(keys[i])), Vector2(price_rect.position.x + 27, price_rect.position.y + 25), 15, WHITE, HORIZONTAL_ALIGNMENT_CENTER, price_rect.size.x - 31, 2)


func draw_missions() -> void:
	var outer := Rect2(14, 694, 512, 168)
	draw_panel(outer, Color("05182c"), CYAN, 3, 9)
	draw_label("MISSIONS", Vector2(27, 722), 20, CYAN, HORIZONTAL_ALIGNMENT_LEFT, 180, 2)
	var titles := ["SMASH 50\nBRICKS", "COLLECT 250\nCASH", "FLY 500\nMETERS"]
	var values := [smashed_total, cash_total, best_meters]
	var targets := [50, 250, 500]
	var rewards := [1000, 1500, 1250]
	for i in 3:
		var card := Rect2(25 + i * 166, 730, 158, 120)
		draw_panel(card, Color("0a3153"), Color("156795"), 2, 6)
		var lines: PackedStringArray = titles[i].split("\n")
		draw_label(lines[0], Vector2(card.position.x + 5, card.position.y + 22), 12, WHITE, HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 10, 2)
		draw_label(lines[1], Vector2(card.position.x + 5, card.position.y + 38), 12, WHITE, HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 10, 2)
		var shown := mini(values[i], targets[i])
		draw_label(str(shown) + "/" + str(targets[i]), Vector2(card.position.x, card.position.y + 62), 16, WHITE, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 2)
		draw_progress(Rect2(card.position.x + 14, card.position.y + 69, card.size.x - 28, 12), float(shown) / float(targets[i]))
		draw_label("REWARD", Vector2(card.position.x + 8, card.position.y + 106), 11, PALE_CYAN, HORIZONTAL_ALIGNMENT_LEFT, 64, 1)
		draw_coin(Vector2(card.position.x + 89, card.position.y + 100), 8)
		draw_label(str(rewards[i]), Vector2(card.position.x + 100, card.position.y + 106), 12, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 50, 1)


func draw_navigation() -> void:
	nav_rects.clear()
	var names := ["SHOP", "CHARACTERS", "PLAY", "LEADERBOARD", "DAILY\nREWARD"]
	for i in 5:
		var rect := Rect2(5 + i * 107, 870, 102, 84)
		nav_rects.append(rect)
		var active := i == 2
		draw_panel(rect, Color("39c83c") if active else Color("082744"), LIME if active else CYAN, 3, 9)
		if active:
			draw_texture_rect(PLAY_TEX, Rect2(rect.position.x + 31, rect.position.y + 8, 40, 40), false)
		var lines: PackedStringArray = names[i].split("\n")
		var y := rect.position.y + 70
		if lines.size() == 1:
			draw_label(lines[0], Vector2(rect.position.x, y), 13 if not active else 17, WHITE, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)
		else:
			draw_label(lines[0], Vector2(rect.position.x, y - 9), 11, WHITE, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)
			draw_label(lines[1], Vector2(rect.position.x, y + 5), 11, WHITE, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)
		if i == 4 and last_daily_date != Time.get_date_string_from_system():
			draw_circle(rect.position + Vector2(87, 13), 12, RED)
			draw_label("!", rect.position + Vector2(78, 20), 16, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 18, 2)


func draw_settings() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0, 0, 0, 0.72))
	var rect := Rect2(70, 260, 400, 340)
	draw_panel(rect, Color("071f38"), CYAN, 4, 15)
	draw_label("SETTINGS", Vector2(70, 316), 34, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 400, 4)
	draw_toggle(Rect2(95, 368, 350, 64), "SOUND", sound_enabled)
	draw_toggle(Rect2(95, 448, 350, 64), "HAPTICS", haptics_enabled)
	draw_label("TAP OUTSIDE TO CLOSE", Vector2(70, 566), 14, PALE_CYAN, HORIZONTAL_ALIGNMENT_CENTER, 400, 2)


func draw_toggle(rect: Rect2, text: String, enabled: bool) -> void:
	draw_panel(rect, Color("0b3153"), Color("156795"), 2, 8)
	draw_label(text, rect.position + Vector2(18, 42), 21, WHITE, HORIZONTAL_ALIGNMENT_LEFT, 180, 2)
	var switch_rect := Rect2(rect.end.x - 102, rect.position.y + 14, 78, 36)
	draw_panel(switch_rect, GREEN if enabled else Color("394b5c"), LIME if enabled else Color("60788a"), 2, 18)
	draw_circle(switch_rect.position + Vector2(59 if enabled else 19, 18), 13, WHITE)


func draw_menu_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0, 0, 0, 0.72))
	var rect := Rect2(60, 220, 420, 500)
	draw_panel(rect, Color("071f38"), CYAN, 4, 15)
	match menu_overlay:
		"shop":
			draw_label("UPGRADE SHOP", Vector2(60, 282), 32, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 420, 4)
			draw_texture_rect(BOOTS_TEX, Rect2(105, 330, 100, 100), false)
			draw_texture_rect(BAZOOKA_TEX, Rect2(270, 350, 130, 80), false)
			draw_label("Tap any upgrade card on the home screen.", Vector2(90, 482), 17, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 360, 2)
			draw_label("Every level improves your run.", Vector2(90, 515), 16, PALE_CYAN, HORIZONTAL_ALIGNMENT_CENTER, 360, 2)
		"characters":
			draw_label("CHARACTERS", Vector2(60, 282), 32, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 420, 4)
			draw_texture_rect(HERO_TEX, Rect2(135, 310, 270, 228), false)
			draw_panel(Rect2(138, 552, 264, 54), Color("27b73f"), LIME, 3, 8)
			draw_label("MAIN HERO • SELECTED", Vector2(138, 588), 17, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 264, 2)
		"leaderboard":
			draw_label("LEADERBOARD", Vector2(60, 282), 32, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 420, 4)
			draw_rank_row(1, "YOU", maxi(best_meters, 0), 335)
			draw_rank_row(2, "BRICK BOT", maxi(best_meters - 45, 0), 402)
			draw_rank_row(3, "ROOFTOP KID", maxi(best_meters - 120, 0), 469)
		"daily":
			draw_label("DAILY REWARD", Vector2(60, 282), 32, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 420, 4)
			draw_texture_rect(CASH_TEX, Rect2(180, 330, 180, 120), false)
			draw_label("500 CASH", Vector2(60, 500), 32, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 420, 4)
			var available := last_daily_date != Time.get_date_string_from_system()
			draw_panel(Rect2(145, 540, 250, 64), Color("2ab43d") if available else Color("344c5b"), LIME if available else Color("60788a"), 3, 9)
			draw_label("CLAIM" if available else "CLAIMED TODAY", Vector2(145, 583), 22, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 250, 3)
	draw_panel(Rect2(120, 635, 300, 58), Color("0b3153"), CYAN, 2, 8)
	draw_label("BACK", Vector2(120, 674), 20, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 300, 2)


func draw_rank_row(rank: int, name: String, meters: int, y: float) -> void:
	draw_panel(Rect2(90, y - 30, 360, 54), Color("0b3153"), Color("156795"), 2, 7)
	draw_label("#" + str(rank), Vector2(102, y + 7), 20, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 50, 2)
	draw_label(name, Vector2(156, y + 7), 17, WHITE, HORIZONTAL_ALIGNMENT_LEFT, 180, 2)
	draw_label(str(meters) + " M", Vector2(330, y + 7), 16, CYAN, HORIZONTAL_ALIGNMENT_CENTER, 105, 2)


func draw_game() -> void:
	current_shake_offset = Vector2.ZERO
	if camera_shake > 0.0:
		current_shake_offset = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * camera_shake * 6.0
	draw_set_transform(current_shake_offset, 0.0, Vector2.ONE)
	draw_sky(false)
	for block in blocks:
		draw_brick(Rect2(block["pos"], block["size"]), int(block["kind"]), int(block["hp"]), int(block["max_hp"]))
	for pickup in pickups:
		var bob := sin(menu_time * 7.0 + pickup["pos"].x) * 3.0
		if bool(pickup["rare"]):
			draw_circle(pickup["pos"] + Vector2(0, bob), 26, Color(0.2, 0.95, 1, 0.22))
			draw_texture_rect(GEM_TEX, Rect2(pickup["pos"] + Vector2(-22, -22 + bob), Vector2(44, 44)), false)
		else:
			draw_texture_rect(CASH_TEX, Rect2(pickup["pos"] + Vector2(-27, -18 + bob), Vector2(54, 36)), false)
	draw_aim_indicator()
	for rocket in rockets:
		var rocket_direction: Vector2 = rocket["vel"].normalized()
		draw_set_transform(current_shake_offset + rocket["pos"], rocket_direction.angle() + PI * 0.5, Vector2.ONE)
		draw_texture_rect(ROCKET_TEX, Rect2(-12, -18, 24, 36), false)
		draw_set_transform(current_shake_offset, 0.0, Vector2.ONE)
	draw_particles()
	draw_player()
	draw_game_hud()
	if screen_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(1, 0.92, 0.68, screen_flash * 0.42))
	if tutorial_visible:
		draw_tutorial()
	elif paused:
		draw_pause()


func draw_aim_indicator() -> void:
	if screen != Screen.GAME or paused or (not aiming and not tutorial_visible):
		return
	var target := Vector2(clampf(last_aim_target.x, 24, 516), clampf(last_aim_target.y, 120, 930))
	var solution := get_aim_solution(target)
	var muzzle: Vector2 = solution["muzzle"]
	var delta := target - muzzle
	if delta.length() < 8:
		return
	var direction := delta.normalized()
	var length := minf(delta.length(), 270.0)
	var color := CYAN if reload_timer <= 0.0 else Color("738a96")
	for distance in range(22, int(length), 24):
		var start := muzzle + direction * float(distance)
		draw_line(start, start + direction * 11.0, color, 3)
	var reticle := muzzle + direction * length
	draw_arc(reticle, 14, 0, TAU, 20, color, 3)
	draw_line(reticle + Vector2(-20, 0), reticle + Vector2(-8, 0), color, 3)
	draw_line(reticle + Vector2(8, 0), reticle + Vector2(20, 0), color, 3)
	draw_line(reticle + Vector2(0, -20), reticle + Vector2(0, -8), color, 3)
	draw_line(reticle + Vector2(0, 8), reticle + Vector2(0, 20), color, 3)


func draw_player() -> void:
	var kick := clampf(recoil_anim / 0.20, 0.0, 1.0)
	var body_rotation := visual_body_rotation + body_angular_kick
	if screen == Screen.GAME_OVER:
		body_rotation = 1.25
	var scale_value := Vector2.ONE
	if player_vel.y < -120:
		scale_value = Vector2(0.96, 1.04)
	elif player_vel.y > 220:
		scale_value = Vector2(1.04, 0.96)
	var tint := WHITE
	if hit_timer > 0 and int(hit_timer * 20) % 2 == 0:
		tint = Color("ff8573")
	var body_kick := -last_shot_direction * kick * 7.0
	if not facing_left:
		scale_value.x *= -1.0
	draw_set_transform(player_pos + current_shake_offset + body_kick, body_rotation, scale_value)
	if flame_timer > 0 and int(upgrades["boots"]) > 1:
		for i in 2:
			var x := 20.0 + float(i) * 31.0
			var length := 26.0 + sin(menu_time * 22 + i) * 6.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 46), Vector2(x - 7, 46), Vector2(x - 2, 46 + length), Vector2(x + 5, 46)]), ORANGE)
			draw_line(Vector2(x, 49), Vector2(x, 60 + length * 0.55), GOLD, 4)
	draw_texture_rect(HERO_BODY_TEX, Rect2(-67, -57, 134, 114), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var weapon_pivot := get_weapon_pivot() + current_shake_offset
	var weapon_recoil_offset := -aim_direction * weapon_kick * 11.0
	var weapon_origin := weapon_pivot + weapon_recoil_offset
	var weapon_draw_state := get_weapon_draw_state()
	draw_set_transform(weapon_origin, weapon_draw_state["rotation"], weapon_draw_state["scale"])
	draw_texture_rect(BAZOOKA_BODY_TEX, Rect2(-68, -31, 80, 63), false)
	if shoot_timer > 0:
		draw_circle(Vector2(-68, 0), 9 + shoot_timer * 24, Color(1, 0.82, 0.22, shoot_timer * 3.4))
		draw_line(Vector2(-65, 0), Vector2(-86 - shoot_timer * 30, 0), GOLD, 6)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var label_offset := Vector2(-36, -2) if weapon_draw_state["points_left"] else Vector2(36, -2)
	var label_position := weapon_origin + label_offset.rotated(weapon_draw_state["rotation"])
	draw_set_transform(label_position, weapon_draw_state["rotation"], Vector2.ONE)
	draw_label("SNW", Vector2(-13, 4), 9, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 26, 1)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_game_hud() -> void:
	draw_panel(Rect2(14, 16, 174, 54), Color(0.01, 0.07, 0.13, 0.92), CYAN, 3, 8)
	draw_coin(Vector2(39, 43), 16)
	draw_label(str(money), Vector2(61, 54), 23, WHITE, HORIZONTAL_ALIGNMENT_LEFT, 116, 2)
	draw_panel(Rect2(197, 16, 260, 54), Color(0.01, 0.07, 0.13, 0.92), CYAN, 3, 8)
	draw_label(str(int(height_meters)) + " METERS", Vector2(197, 54), 23, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 260, 3)
	draw_panel(pause_rect, Color("08233e"), CYAN, 3, 8)
	draw_rect(Rect2(489, 32, 7, 22), WHITE)
	draw_rect(Rect2(503, 32, 7, 22), WHITE)
	draw_panel(Rect2(14, 78, 156, 36), Color(0.01, 0.07, 0.13, 0.82), Color("156795"), 2, 6)
	draw_texture_rect(CASH_TEX, Rect2(24, 84, 36, 24), false)
	draw_label("RUN +" + str(run_cash), Vector2(65, 103), 15, LIME, HORIZONTAL_ALIGNMENT_LEFT, 96, 2)
	var reload_rect := Rect2(197, 79, 205, 32)
	draw_panel(reload_rect, Color(0.01, 0.07, 0.13, 0.86), Color("156795"), 2, 6)
	var ready := reload_timer <= 0.0
	draw_label("BAZOOKA READY" if ready else "RELOADING", Vector2(reload_rect.position.x, reload_rect.position.y + 22), 13, LIME if ready else WHITE, HORIZONTAL_ALIGNMENT_CENTER, reload_rect.size.x, 2)
	if not ready:
		draw_progress(Rect2(reload_rect.position.x + 5, reload_rect.end.y - 6, reload_rect.size.x - 10, 5), 1.0 - reload_timer / 0.56)
	if shield_available:
		draw_texture_rect(SHIELD_TEX, Rect2(478, 81, 44, 44), false)


func draw_tutorial() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0, 0, 0, 0.30))
	draw_panel(Rect2(62, 690, 416, 158), Color(0.01, 0.08, 0.14, 0.94), CYAN, 4, 13)
	draw_label("AIM BELOW THE HERO", Vector2(62, 741), 28, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 416, 4)
	draw_label("HOLD • DRAG • RELEASE", Vector2(62, 780), 22, LIME, HORIZONTAL_ALIGNMENT_CENTER, 416, 3)
	draw_label("Aim at a brick, release to fire", Vector2(62, 816), 16, PALE_CYAN, HORIZONTAL_ALIGNMENT_CENTER, 416, 2)
	draw_label("BAZOOKA IS YOUR ENGINE", Vector2(62, 839), 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 416, 2)


func draw_pause() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0, 0, 0, 0.70))
	draw_panel(Rect2(75, 315, 390, 315), Color("071f38"), CYAN, 4, 14)
	draw_label("PAUSED", Vector2(75, 392), 42, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 390, 5)
	draw_panel(Rect2(120, 440, 300, 62), Color("2ab43d"), LIME, 3, 9)
	draw_label("RESUME", Vector2(120, 482), 23, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 300, 3)
	draw_panel(Rect2(120, 520, 300, 62), Color("0b3153"), CYAN, 3, 9)
	draw_label("HOME", Vector2(120, 562), 23, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 300, 3)


func draw_game_over() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0, 0, 0, 0.76))
	draw_panel(Rect2(52, 232, 436, 570), Color("071f38"), CYAN, 5, 16)
	draw_label("GAME OVER", Vector2(52, 315), 47, ORANGE, HORIZONTAL_ALIGNMENT_CENTER, 436, 6)
	draw_texture_rect(HERO_TEX, Rect2(164, 330, 212, 180), false, Color(0.72, 0.72, 0.76, 1))
	draw_label(str(int(height_meters)) + " METERS", Vector2(52, 544), 30, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 436, 4)
	draw_label("CASH +" + str(run_cash), Vector2(52, 582), 22, LIME, HORIZONTAL_ALIGNMENT_CENTER, 436, 3)
	draw_panel(Rect2(92, 618, 356, 70), Color("2ab43d"), LIME, 4, 10)
	draw_label("RESTART", Vector2(92, 666), 29, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 356, 4)
	draw_panel(Rect2(92, 705, 356, 62), Color("0b3153"), CYAN, 3, 9)
	draw_label("HOME", Vector2(92, 747), 23, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 356, 3)


func draw_particles() -> void:
	for particle in particles:
		var alpha := clampf(float(particle["life"]) / float(particle["max_life"]), 0, 1)
		var color: Color = particle["color"]
		color.a = alpha
		var size: float = float(particle["size"])
		draw_rect(Rect2(particle["pos"] - Vector2(size, size) * 0.5, Vector2(size, size)), color)


func draw_brick(rect: Rect2, kind: int, hp: int, max_hp: int) -> void:
	draw_texture_rect(BRICK_TEX, rect, false)
	if kind == 1:
		draw_rect(rect.grow(-3), Color(0.25, 0.32, 0.38, 0.72), false, 5)
		for x in range(int(rect.position.x + 18), int(rect.end.x - 8), 28):
			draw_circle(Vector2(x, rect.position.y + 10), 3, Color("c8d3da"))
	elif kind == 2:
		var points := PackedVector2Array([
			rect.position + Vector2(12, 34), rect.position + Vector2(30, 16),
			rect.position + Vector2(50, 38), rect.position + Vector2(72, 14),
			rect.position + Vector2(92, 37), rect.position + Vector2(112, 19)
		])
		draw_polyline(points, CYAN, 6)
	elif kind == 3:
		draw_coin(rect.get_center(), 16)
	if hp < max_hp:
		draw_line(rect.position + Vector2(rect.size.x * 0.48, 4), rect.position + Vector2(rect.size.x * 0.38, 24), INK, 4)
		draw_line(rect.position + Vector2(rect.size.x * 0.38, 24), rect.position + Vector2(rect.size.x * 0.55, 39), INK, 4)


func draw_coin(center: Vector2, radius: float) -> void:
	draw_circle(center + Vector2(2, 3), radius + 2, Color("5d3b10"))
	draw_circle(center, radius, GOLD)
	draw_circle(center, radius * 0.70, Color("f3ae16"))
	draw_label("$", center + Vector2(-radius, radius * 0.55), int(radius * 1.15), WHITE, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, 1)


func draw_progress(rect: Rect2, value: float) -> void:
	draw_panel(rect, Color("020b15"), Color("0f1e2c"), 2, 4)
	var inner := rect.grow(-3)
	inner.size.x *= clampf(value, 0, 1)
	if inner.size.x > 0:
		draw_rect(inner, LIME)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, maxf(2, inner.size.y * 0.3))), Color("c2ff54"))


func draw_panel(rect: Rect2, fill: Color, border: Color, border_width: int = 3, radius: int = 8) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 5
	box.shadow_offset = Vector2(0, 4)
	draw_style_box(box, rect)


func draw_label(text: String, baseline: Vector2, size: int, color: Color, alignment: HorizontalAlignment, width: float, outline: int = 2) -> void:
	var font := ThemeDB.fallback_font
	if outline > 0:
		var offsets := [Vector2(-outline, 0), Vector2(outline, 0), Vector2(0, -outline), Vector2(0, outline), Vector2(-outline, -outline), Vector2(outline, outline)]
		for offset in offsets:
			draw_string(font, baseline + offset, text, alignment, width, size, INK)
	draw_string(font, baseline, text, alignment, width, size, color)


func draw_toast() -> void:
	var width := clampf(150 + toast_text.length() * 8, 240, 440)
	var rect := Rect2((540 - width) * 0.5, 125, width, 48)
	draw_panel(rect, Color(0.01, 0.07, 0.13, 0.95), GOLD, 3, 9)
	draw_label(toast_text, Vector2(rect.position.x, rect.position.y + 33), 17, WHITE, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)

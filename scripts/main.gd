extends Node2D

enum Screen { MENU, GAME, GAME_OVER }

const VIEW_SIZE := Vector2(540.0, 960.0)
const SAVE_PATH := "user://brick_bazuka_save.cfg"
const INITIAL_BLOCK_ROWS := 4
const BLOCK_GAP_MIN := 250.0
const BLOCK_GAP_MAX := 310.0
const PLAYER_GRAVITY := 690.0
const PLATFORM_JUMP_HEIGHT := BLOCK_GAP_MAX + 60.0
const PLATFORM_BOUNCE_SPEED := sqrt(2.0 * PLAYER_GRAVITY * PLATFORM_JUMP_HEIGHT)
const SPRING_BOOST_DURATION := 8.0
const SPRING_BOUNCE_SPEED := sqrt(2.0 * PLAYER_GRAVITY * PLATFORM_JUMP_HEIGHT * 2.0)
const SPRING_SIZE := Vector2(60, 48)
const STEERING_SPEED := 320.0
const STEERING_ACCELERATION := 1800.0
const GHOST_SPAWN_CHANCE := 0.38
const GHOST_ALERT_DISTANCE := 200.0
const GHOST_CALM_DISTANCE := 250.0
const GHOST_TRANSITION_TIME := 0.12
const GHOST_DEATH_PLAYBACK_SPEED := 2.0
const GHOST_DRAW_SIZE := Vector2(92, 92)
const MAX_HEALTH := 3

const HERO_TEX := preload("res://assets/characters/main_hero.png")
const HERO_BODY_TEX := preload("res://assets/characters/main_hero_body.png")
const MENU_COVER_TEX := preload("res://assets/backgrounds/menu_cover.png")
const NIGHT_CITY_VIDEO := preload("res://assets/backgrounds/night_city_loop.ogv")
const NIGHT_CITY_POSTER := preload("res://assets/backgrounds/night_city_poster.png")
const GHOST_FRAMES := preload("res://assets/characters/ghost/animations.tres")
const SCORE_DIGITS_TEX := preload("res://assets/ui/score_digits.svg")
const TAP_GLOVE_TEX := preload("res://assets/ui/tap_glove_down.png")
const LEADERBOARD_UI := preload("res://scripts/leaderboard.gd")
const TILT_CONTROL := preload("res://scripts/tilt_control.gd")
const BAZOOKA_BODY_TEX := preload("res://assets/weapons/bazooka_body.png")
const ROCKET_TEX := preload("res://assets/weapons/rocket.svg")
const SPRING_TEX := preload("res://assets/powerups/spring.svg")

# Clip the baked-in boot exhaust at the soles without changing the supplied sprite.
const HERO_BODY_OUTLINE := [
	Vector2(0, 0), Vector2(1368, 0), Vector2(1368, 750), Vector2(1124, 750),
	Vector2(1110, 766), Vector2(1100, 781), Vector2(1075, 798), Vector2(1033, 812),
	Vector2(1018, 823), Vector2(1018, 841), Vector2(1007, 860), Vector2(980, 895), Vector2(941, 918),
	Vector2(903, 931), Vector2(866, 934), Vector2(830, 925), Vector2(800, 906),
	Vector2(788, 879), Vector2(785, 842), Vector2(769, 830), Vector2(741, 833),
	Vector2(723, 850), Vector2(690, 860), Vector2(661, 867), Vector2(634, 875),
	Vector2(604, 879), Vector2(572, 882), Vector2(532, 882), Vector2(495, 880),
	Vector2(471, 876), Vector2(451, 862), Vector2(0, 862)
]

const PLATFORM_SHEETS := [
	preload("res://assets/blocks/reference_brick.png"),
	preload("res://assets/blocks/reference_stone.png"),
	preload("res://assets/blocks/reference_mixed.png")
]
const PLATFORM_SHADER := preload("res://assets/blocks/platform_key.gdshader")
# Each region follows the supplied artwork's outline and natural proportions.
# Reinforced platforms switch to a cracked region after their first hit.
const PLATFORM_ART := [
	{"sheet": 0, "region": Rect2(257, 190, 453, 173), "kind": 0},
	{"sheet": 0, "region": Rect2(825, 190, 593, 173), "kind": 0},
	{"sheet": 0, "region": Rect2(47, 517, 448, 173), "kind": 0},
	{"sheet": 0, "region": Rect2(566, 517, 541, 173), "kind": 0},
	{"sheet": 0, "region": Rect2(1178, 509, 452, 181), "kind": 2},
	{"sheet": 1, "region": Rect2(102, 173, 558, 190), "kind": 1, "hp": 2, "damaged": 7},
	{"sheet": 1, "region": Rect2(800, 171, 713, 192), "kind": 1, "hp": 2, "damaged": 8},
	{"sheet": 1, "region": Rect2(41, 527, 482, 195), "kind": 1},
	{"sheet": 1, "region": Rect2(572, 527, 532, 195), "kind": 1},
	{"sheet": 1, "region": Rect2(1151, 527, 483, 232), "kind": 2},
	{"sheet": 2, "region": Rect2(50, 197, 657, 294), "kind": 0},
	{"sheet": 2, "region": Rect2(772, 196, 638, 340), "kind": 1},
	{"sheet": 2, "region": Rect2(1474, 195, 652, 341), "kind": 2}
]

const INK := Color("071426")
const DEEP := Color("061b39")
const PANEL_BLUE := Color("082b4b")
const CYAN := Color("80df41")
const PALE_CYAN := Color("d6f4ae")
const ORANGE := Color("f06a28")
const GOLD := Color("ffd238")
const LIME := Color("78e43b")
const GREEN := Color("28b947")
const WHITE := Color("f5f8ee")
const RED := Color("ff493d")

var screen := Screen.MENU
var profile_path := SAVE_PATH
var paused := false
var tutorial_visible := false
var tutorial_time := 0.0
var sound_enabled := true
var haptics_enabled := true
var menu_time := 0.0
var toast_text := ""
var toast_timer := 0.0

var smashed_total := 0
var best_meters := 0
var player_name := ""
var leaderboard
var tilt_control

var rng := RandomNumberGenerator.new()
var player_pos := Vector2.ZERO
var player_vel := Vector2.ZERO
var height_meters := 0.0
var shoot_timer := 0.0
var reload_timer := 0.0
var hit_timer := 0.0
var contact_cooldown := 0.0
var damage_flash := 0.0
var health := MAX_HEALTH
var spring_boost_timer := 0.0
var platforms_until_spring := 2
var hero_body_polygon := PackedVector2Array()
var hero_body_uvs := PackedVector2Array()
var camera_shake := 0.0
var screen_flash := 0.0
var last_shot_direction := Vector2.DOWN
var aim_direction := Vector2.DOWN
var last_aim_target := Vector2(270, 820)
var aiming := false
var visual_body_rotation := 0.0
var visual_weapon_rotation := PI * 0.5
var weapon_kick := 0.0
var facing_left := false
var weapon_anchor_x := 22.0
var current_shake_offset := Vector2.ZERO
var spawn_cursor_y := -100.0
var blocks: Array = []
var ghosts: Array = []
var ghost_deaths: Array = []
var rockets: Array = []
var particles: Array = []
var platform_layer: Node2D
var background_layer: Control
var background_video: VideoStreamPlayer

var cta_rect := Rect2(151, 754, 238, 90)


func _ready() -> void:
	rng.randomize()
	load_profile()
	for point in HERO_BODY_OUTLINE:
		var uv: Vector2 = point / HERO_BODY_TEX.get_size()
		hero_body_uvs.append(uv)
		hero_body_polygon.append(Vector2(-67, -57) + uv * Vector2(134, 114))
	tilt_control = TILT_CONTROL.new()
	add_child(tilt_control)
	setup_video_background()
	setup_platform_layer()
	leaderboard = LEADERBOARD_UI.new()
	leaderboard.last_name = player_name
	leaderboard.restart_requested.connect(start_game)
	leaderboard.home_requested.connect(return_to_menu)
	leaderboard.player_name_changed.connect(func(value: String): player_name = value; save_profile())
	add_child(leaderboard)
	if OS.get_cmdline_user_args().has("--capture-game"):
		start_game()
		tutorial_visible = false
		launch_player(Vector2(360, 820))
	elif OS.get_cmdline_user_args().has("--capture-ghosts"):
		start_game()
		tutorial_visible = false
		ghosts = [
			make_ghost(Vector2(105, 255), 0.0),
			make_ghost(Vector2(390, 390), 0.0),
			make_ghost(Vector2(200, 535), 0.0)
		]
	queue_redraw()


func setup_platform_layer() -> void:
	platform_layer = Node2D.new()
	platform_layer.name = "Platforms"
	platform_layer.z_index = -1
	platform_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var keyed_material := ShaderMaterial.new()
	keyed_material.shader = PLATFORM_SHADER
	platform_layer.material = keyed_material
	platform_layer.draw.connect(draw_platforms)
	add_child(platform_layer)


func draw_platforms() -> void:
	for block in blocks:
		var art: Dictionary = PLATFORM_ART[int(block.get("skin", 0))]
		if int(block["hp"]) < int(block["max_hp"]) and art.has("damaged"):
			art = PLATFORM_ART[int(art["damaged"])]
		platform_layer.draw_texture_rect_region(PLATFORM_SHEETS[int(art["sheet"])], Rect2(block["pos"], block["size"]), art["region"])


func setup_video_background() -> void:
	background_layer = Control.new()
	background_layer.name = "VideoBackground"
	background_layer.z_index = -10
	background_layer.size = VIEW_SIZE
	background_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_layer)
	var poster := TextureRect.new()
	poster.texture = NIGHT_CITY_POSTER
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.size = VIEW_SIZE
	poster.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_layer.add_child(poster)
	background_video = VideoStreamPlayer.new()
	background_video.name = "NightCityLoop"
	background_video.stream = NIGHT_CITY_VIDEO
	background_video.expand = true
	background_video.size = VIEW_SIZE
	background_video.loop = true
	background_video.volume = 0.0
	background_video.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_layer.add_child(background_video)
	sync_video_background()


func sync_video_background() -> void:
	if not is_instance_valid(background_video):
		return
	background_layer.visible = screen != Screen.MENU
	if screen == Screen.MENU:
		if background_video.is_playing():
			background_video.stop()
		return
	if not background_video.is_playing():
		background_video.play()
	background_video.paused = paused or tutorial_visible or screen == Screen.GAME_OVER or tilt_control.needs_permission()


func _process(delta: float) -> void:
	sync_video_background()
	menu_time += delta
	if tutorial_visible and not paused:
		tutorial_time += delta
	toast_timer = maxf(0.0, toast_timer - delta)
	shoot_timer = maxf(0.0, shoot_timer - delta)
	reload_timer = maxf(0.0, reload_timer - delta)
	hit_timer = maxf(0.0, hit_timer - delta)
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	damage_flash = maxf(0.0, damage_flash - delta * 3.0)
	weapon_kick = maxf(0.0, weapon_kick - delta * 6.5)
	camera_shake = maxf(0.0, camera_shake - delta * 3.8)
	screen_flash = maxf(0.0, screen_flash - delta * 4.5)
	if screen == Screen.GAME:
		update_visual_controller(delta)
	if screen == Screen.GAME and not paused and not tutorial_visible and not tilt_control.needs_permission():
		update_game(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if screen == Screen.GAME_OVER:
		return
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
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]:
			if screen == Screen.GAME and not paused:
				tutorial_visible = false
		elif key == KEY_SPACE or key == KEY_ENTER:
			if screen == Screen.MENU:
				start_game()
			elif screen == Screen.GAME:
				if paused:
					paused = false
				else:
					handle_game_press(player_pos + Vector2(0, 260))
		elif key == KEY_ESCAPE:
			if screen == Screen.GAME:
				aiming = false
				paused = not paused


func begin_aim(position: Vector2) -> void:
	if paused:
		handle_game_press(position)
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
	if not aiming and shoot_timer <= 0.0:
		desired_body_rotation = clampf(player_vel.x / 720.0 * deg_to_rad(24.0), -deg_to_rad(28.0), deg_to_rad(28.0))
	var body_weight := 1.0 - exp(-7.0 * delta)
	visual_body_rotation = lerp_angle(visual_body_rotation, desired_body_rotation, body_weight)
	var desired_anchor_x := -22.0 if facing_left else 22.0
	weapon_anchor_x = lerpf(weapon_anchor_x, desired_anchor_x, 1.0 - exp(-14.0 * delta))


func get_weapon_pivot() -> Vector2:
	var local_anchor := Vector2(weapon_anchor_x, -16)
	return player_pos + local_anchor.rotated(visual_body_rotation)


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


func handle_menu_press(position: Vector2) -> void:
	if cta_rect.has_point(position):
		start_game()


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
	launch_player(position)


func start_game() -> void:
	leaderboard.start_run()
	tilt_control.start()
	screen = Screen.GAME
	paused = false
	player_pos = Vector2(270, 665)
	player_vel = Vector2(0, -80)
	height_meters = 0.0
	shoot_timer = 0.0
	reload_timer = 0.0
	hit_timer = 0.0
	contact_cooldown = 0.0
	damage_flash = 0.0
	health = MAX_HEALTH
	spring_boost_timer = 0.0
	platforms_until_spring = 2
	weapon_kick = 0.0
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
	ghosts.clear()
	ghost_deaths.clear()
	rockets.clear()
	particles.clear()
	spawn_cursor_y = 760.0
	for i in INITIAL_BLOCK_ROWS:
		spawn_block(spawn_cursor_y)
		spawn_cursor_y -= rng.randf_range(BLOCK_GAP_MIN, BLOCK_GAP_MAX)
	tutorial_visible = true
	tutorial_time = 0.0
	if is_instance_valid(background_video):
		background_video.stop()
	sync_video_background()


func return_to_menu() -> void:
	leaderboard.dismiss()
	tilt_control.stop()
	screen = Screen.MENU
	paused = false
	tutorial_visible = false
	sync_video_background()
	save_profile()


func launch_player(target: Vector2) -> void:
	last_aim_target = target
	if reload_timer > 0.0:
		return
	var solution := get_aim_solution(target)
	var muzzle_position: Vector2 = solution["muzzle"]
	var shot_direction: Vector2 = solution["direction"]
	last_shot_direction = shot_direction
	aim_direction = shot_direction
	if shot_direction.x < 0.0:
		facing_left = true
	elif shot_direction.x > 0.0:
		facing_left = false
	reload_timer = 0.56
	shoot_timer = 0.20
	weapon_kick = 1.0
	screen_flash = 0.26
	rockets.append({"pos": muzzle_position, "vel": shot_direction * 690.0, "life": 2.2, "trail": 0.0})
	spawn_muzzle(muzzle_position, shot_direction)


func update_game(delta: float) -> void:
	spring_boost_timer = maxf(0.0, spring_boost_timer - delta)
	player_vel.y += PLAYER_GRAVITY * delta
	player_vel.x = move_toward(player_vel.x, tilt_control.read_axis() * STEERING_SPEED, STEERING_ACCELERATION * delta)
	player_pos += player_vel * delta
	player_pos.x = wrapf(player_pos.x, 0.0, VIEW_SIZE.x)

	var camera_shift := 0.0
	if player_pos.y < 345:
		camera_shift = 345.0 - player_pos.y
		player_pos.y = 345.0
		height_meters += camera_shift * 0.19
		shift_world(camera_shift)

	spawn_world_if_needed()
	update_ghosts(delta)
	update_ghost_deaths(delta)
	update_rockets(delta)
	update_particles(delta)
	check_player_block_collisions()
	if player_pos.y > 1040:
		lose_heart()
		if screen == Screen.GAME:
			player_pos.y = 770
			player_vel = Vector2(0, -362)
		cleanup_world()
		return
	check_player_ghost_collisions()
	if screen != Screen.GAME:
		return
	cleanup_world()


func shift_world(amount: float) -> void:
	for block in blocks:
		block["pos"] = block["pos"] + Vector2(0, amount)
	for ghost in ghosts:
		ghost["pos"] = ghost["pos"] + Vector2(0, amount)
	for death in ghost_deaths:
		death["pos"] = death["pos"] + Vector2(0, amount)
	for rocket in rockets:
		rocket["pos"] = rocket["pos"] + Vector2(0, amount)
	for particle in particles:
		particle["pos"] = particle["pos"] + Vector2(0, amount)
	spawn_cursor_y += amount


func spawn_world_if_needed() -> void:
	while spawn_cursor_y > -260:
		spawn_block(spawn_cursor_y)
		spawn_cursor_y -= rng.randf_range(BLOCK_GAP_MIN, BLOCK_GAP_MAX)


func spawn_block(y_position: float) -> void:
	var skin := rng.randi_range(0, PLATFORM_ART.size() - 1)
	var art: Dictionary = PLATFORM_ART[skin]
	var region: Rect2 = art["region"]
	var width := rng.randf_range(150, 185)
	if region.size.x / region.size.y > 3.0:
		width = rng.randf_range(185, 215)
	var size := Vector2(width, width * region.size.y / region.size.x)
	var x := rng.randf_range(22.0, 518.0 - width)
	var hp := int(art.get("hp", 1))
	var has_spring := platforms_until_spring <= 0
	platforms_until_spring = rng.randi_range(4, 6) if has_spring else platforms_until_spring - 1
	blocks.append({"pos": Vector2(x, y_position), "size": size, "skin": skin, "kind": int(art["kind"]), "hp": hp, "max_hp": hp, "spring": has_spring})
	# Keep spring takeoffs clear; ordinary rows can have a drifting ghost above a brick.
	if not has_spring and y_position < 520.0 and rng.randf() < GHOST_SPAWN_CHANCE:
		ghosts.append(make_ghost(Vector2(clampf(x + width * 0.5 + rng.randf_range(-55, 55), 55, 485), y_position - 79), rng.randf_range(34, 62) * (-1.0 if rng.randf() < 0.5 else 1.0)))


func make_ghost(position: Vector2, horizontal_speed: float) -> Dictionary:
	return {"pos": position, "vx": horizontal_speed, "phase": rng.randf_range(0, TAU),
		"state": "idle", "animation_time": rng.randf_range(0, ghost_clip_duration("idle")),
		"transition": GHOST_TRANSITION_TIME, "previous_state": "idle", "previous_time": 0.0}


func ghost_clip_duration(clip: String) -> float:
	return float(GHOST_FRAMES.get_frame_count(clip)) / GHOST_FRAMES.get_animation_speed(clip)


func ghost_frame(clip: String, animation_time: float) -> Texture2D:
	var count := GHOST_FRAMES.get_frame_count(clip)
	var frame := int(animation_time * GHOST_FRAMES.get_animation_speed(clip))
	frame = frame % count if GHOST_FRAMES.get_animation_loop(clip) else mini(frame, count - 1)
	return GHOST_FRAMES.get_frame_texture(clip, frame)


func update_ghosts(delta: float) -> void:
	for ghost in ghosts:
		var old_phase: float = ghost["phase"]
		ghost["phase"] = old_phase + delta * 2.2
		var position: Vector2 = ghost["pos"]
		position += Vector2(float(ghost["vx"]) * delta, (sin(float(ghost["phase"])) - sin(old_phase)) * 11.0)
		if position.x < 48.0 or position.x > 492.0:
			position.x = clampf(position.x, 48, 492)
			ghost["vx"] = -float(ghost["vx"])
		ghost["pos"] = position
		var state: String = ghost.get("state", "idle")
		var distance := position.distance_to(player_pos)
		var next_state := state
		if state == "idle" and distance <= GHOST_ALERT_DISTANCE:
			next_state = "alert"
		elif state == "alert" and distance >= GHOST_CALM_DISTANCE:
			next_state = "idle"
		if next_state != state:
			ghost["previous_state"] = state
			ghost["previous_time"] = ghost.get("animation_time", 0.0)
			ghost["state"] = next_state
			ghost["animation_time"] = 0.0
			ghost["transition"] = 0.0
		ghost["animation_time"] = fmod(float(ghost.get("animation_time", 0.0)) + delta, ghost_clip_duration(next_state))
		ghost["transition"] = minf(float(ghost.get("transition", GHOST_TRANSITION_TIME)) + delta, GHOST_TRANSITION_TIME)


func update_ghost_deaths(delta: float) -> void:
	for index in range(ghost_deaths.size() - 1, -1, -1):
		ghost_deaths[index]["time"] = float(ghost_deaths[index]["time"]) + delta * GHOST_DEATH_PLAYBACK_SPEED
		if float(ghost_deaths[index]["time"]) >= ghost_clip_duration("death"):
			ghost_deaths.remove_at(index)


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
		var hit_ghost := false
		for ghost in ghosts:
			if rocket["pos"].distance_to(ghost["pos"]) < 32.0:
				hit_ghost = true
				break
		if not hit_ghost:
			for block_index in range(blocks.size() - 1, -1, -1):
				var block = blocks[block_index]
				if rocket_rect.intersects(Rect2(block["pos"], block["size"])):
					hit_index = block_index
					break
		if hit_ghost or hit_index >= 0:
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
	var radius := 60.0
	for index in range(blocks.size() - 1, -1, -1):
		var block = blocks[index]
		var center: Vector2 = block["pos"] + block["size"] * 0.5
		if index == direct_index:
			damage_block(index, 1)
		elif center.distance_to(position) <= radius:
			damage_block(index, 1)
	pop_ghosts_near(position, radius)


func pop_ghosts_near(position: Vector2, radius: float) -> void:
	for index in range(ghosts.size() - 1, -1, -1):
		if ghosts[index]["pos"].distance_to(position) <= radius:
			var center: Vector2 = ghosts[index]["pos"]
			ghosts.remove_at(index)
			spawn_ghost_pop(center)


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
	else:
		blocks[index] = block
		spawn_hit_sparks(block["pos"] + block["size"] * 0.5)


func spring_rect(block: Dictionary) -> Rect2:
	return Rect2(block["pos"] + Vector2((block["size"].x - SPRING_SIZE.x) * 0.5, -SPRING_SIZE.y), SPRING_SIZE)


func check_player_block_collisions() -> void:
	if player_vel.y <= 0:
		return
	var feet := Rect2(player_pos + Vector2(-35, 30), Vector2(70, 38))
	for index in range(blocks.size() - 1, -1, -1):
		var block = blocks[index]
		var block_rect := Rect2(block["pos"], block["size"])
		if block.get("spring", false):
			var spring := spring_rect(block)
			if feet.intersects(spring) and player_pos.y < spring.position.y + 16:
				block["spring"] = false
				spring_boost_timer = SPRING_BOOST_DURATION
				player_pos.y = spring.position.y - 48
				player_vel.y = -SPRING_BOUNCE_SPEED
				show_toast("СУПЕРПРЫЖОК!")
				damage_block(index, 1)
				return
		if feet.intersects(block_rect) and player_pos.y < block_rect.position.y + 16:
			player_pos.y = block_rect.position.y - 48
			player_vel.y = -SPRING_BOUNCE_SPEED if spring_boost_timer > 0.0 else -PLATFORM_BOUNCE_SPEED
			hit_timer = 0.12
			damage_block(index, 1)
			return


func check_player_ghost_collisions() -> void:
	if screen != Screen.GAME or contact_cooldown > 0.0:
		return
	for ghost in ghosts:
		var offset: Vector2 = player_pos + Vector2(0, -7) - ghost["pos"]
		if offset.length() > 45.0:
			continue
		player_vel = Vector2(240.0 if offset.x >= 0 else -240.0, -320.0)
		player_pos += offset.normalized() * 12.0 if offset.length() > 1.0 else Vector2(0, -12)
		lose_heart()
		return


func lose_heart() -> void:
	if screen != Screen.GAME:
		return
	health = maxi(0, health - 1)
	contact_cooldown = 1.25
	hit_timer = 0.9
	damage_flash = 0.7
	camera_shake = 1.0
	show_toast("-1 ЖИЗНЬ")
	if health == 0:
		finish_run()


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
	for index in range(ghosts.size() - 1, -1, -1):
		if ghosts[index]["pos"].y > 1080:
			ghosts.remove_at(index)


func finish_run() -> void:
	if screen == Screen.GAME_OVER:
		return
	screen = Screen.GAME_OVER
	tilt_control.stop()
	best_meters = maxi(best_meters, int(height_meters))
	save_profile()
	leaderboard.show_results(int(height_meters))


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
	elif kind == 2:
		colors = [Color("658b16"), Color("344920"), Color("b1c735")]
	for i in 15:
		particles.append(make_particle(position, Vector2(rng.randf_range(-230, 230), rng.randf_range(-260, -40)), colors[i % colors.size()], rng.randf_range(5, 12), rng.randf_range(0.55, 0.95), 540))


func spawn_hit_sparks(position: Vector2) -> void:
	for i in 7:
		particles.append(make_particle(position, Vector2(rng.randf_range(-150, 150), rng.randf_range(-170, 20)), WHITE if i % 2 == 0 else GOLD, rng.randf_range(3, 7), 0.35, 250))


func spawn_ghost_pop(position: Vector2) -> void:
	ghost_deaths.append({"pos": position, "time": 0.0})


func make_particle(position: Vector2, velocity: Vector2, color: Color, size: float, life: float, gravity: float) -> Dictionary:
	return {"pos": position, "vel": velocity, "color": color, "size": size, "life": life, "max_life": life, "gravity": gravity}


func show_toast(text: String) -> void:
	toast_text = text
	toast_timer = 2.0


func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(profile_path) != OK:
		return
	smashed_total = int(config.get_value("progress", "smashed_total", 0))
	best_meters = int(config.get_value("progress", "best_meters", 0))
	player_name = str(config.get_value("player", "name", "")).left(20)
	sound_enabled = bool(config.get_value("settings", "sound", true))
	haptics_enabled = bool(config.get_value("settings", "haptics", true))


func save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "smashed_total", smashed_total)
	config.set_value("progress", "best_meters", best_meters)
	config.set_value("player", "name", player_name)
	config.set_value("settings", "sound", sound_enabled)
	config.set_value("settings", "haptics", haptics_enabled)
	config.save(profile_path)


func _exit_tree() -> void:
	save_profile()


func _draw() -> void:
	if is_instance_valid(platform_layer):
		platform_layer.visible = screen != Screen.MENU
		platform_layer.queue_redraw()
	if screen == Screen.MENU:
		draw_menu()
	elif screen == Screen.GAME:
		draw_game()
	else:
		draw_game()
	if toast_timer > 0 and screen != Screen.MENU:
		draw_toast()


func draw_menu() -> void:
	draw_texture_rect(MENU_COVER_TEX, Rect2(Vector2.ZERO, VIEW_SIZE), false)
	var pulse := 0.35 + 0.25 * sin(menu_time * 3.4)
	draw_rect(cta_rect.grow(3), Color(0.59, 1.0, 0.13, pulse), false, 3)
	if tilt_control.uses_keyboard():
		draw_keyboard_help(852.0, true)


func draw_keyboard_help(top: float, show_start: bool = false) -> void:
	draw_panel(Rect2(40, top, 460, 88), Color(0.02, 0.07, 0.12, 0.94), CYAN, 2, 10)
	draw_label("СТРЕЛКИ / A D — ДВИЖЕНИЕ", Vector2(40, top + 28), 19, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 460, 1)
	draw_label("ПРОБЕЛ — ВЫСТРЕЛ   ·   ESC — ПАУЗА", Vector2(40, top + 53), 16, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 460, 1)
	var hint := "ENTER — НАЧАТЬ" if show_start else "ПРЫЖОК ОТ ПЛАТФОРМЫ — АВТОМАТИЧЕСКИ"
	draw_label(hint, Vector2(40, top + 75), 13, PALE_CYAN, HORIZONTAL_ALIGNMENT_CENTER, 460, 1)


func draw_enemy_ghost(ghost: Dictionary) -> void:
	var clip: String = ghost.get("state", "idle")
	var rect := Rect2(ghost["pos"] - GHOST_DRAW_SIZE * 0.5, GHOST_DRAW_SIZE)
	var blend := clampf(float(ghost.get("transition", GHOST_TRANSITION_TIME)) / GHOST_TRANSITION_TIME, 0.0, 1.0)
	if blend < 1.0:
		draw_texture_rect(ghost_frame(ghost.get("previous_state", "idle"), float(ghost.get("previous_time", 0.0))), rect, false, Color(1, 1, 1, 1.0 - blend))
	draw_texture_rect(ghost_frame(clip, float(ghost.get("animation_time", 0.0))), rect, false, Color(1, 1, 1, blend))


func draw_ghost_deaths() -> void:
	for death in ghost_deaths:
		var elapsed: float = death["time"]
		# Let the supplied dispersal finish, then fade only its remaining edge wisps.
		var alpha := clampf((ghost_clip_duration("death") - elapsed) / 0.18, 0.0, 1.0)
		var size := GHOST_DRAW_SIZE * lerpf(1.0, 1.5, clampf(elapsed / 0.8, 0.0, 1.0))
		draw_texture_rect(ghost_frame("death", elapsed), Rect2(death["pos"] - size * 0.5, size), false, Color(1, 1, 1, alpha))


func draw_game() -> void:
	current_shake_offset = Vector2.ZERO
	if camera_shake > 0.0:
		current_shake_offset = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * camera_shake * 6.0
	draw_set_transform(current_shake_offset, 0.0, Vector2.ONE)
	platform_layer.position = current_shake_offset
	for block in blocks:
		if block.get("spring", false):
			draw_texture_rect(SPRING_TEX, spring_rect(block), false)
	for ghost in ghosts:
		draw_enemy_ghost(ghost)
	draw_ghost_deaths()
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
	if damage_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(1, 0.13, 0.18, damage_flash * 0.25))
	if tutorial_visible:
		draw_tutorial()
	elif paused:
		draw_pause()


func draw_aim_indicator() -> void:
	if screen != Screen.GAME or paused or not aiming:
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
	var body_rotation := visual_body_rotation
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
	if not facing_left:
		scale_value.x *= -1.0
	draw_set_transform(player_pos + current_shake_offset, body_rotation, scale_value)
	draw_polygon(hero_body_polygon, PackedColorArray([tint]), hero_body_uvs, HERO_BODY_TEX)
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
	draw_score_counter()
	if spring_boost_timer > 0.0:
		draw_texture_rect(SPRING_TEX, Rect2(204, 127, 30, 24), false)
		draw_rect(Rect2(244, 132, 92, 14), INK)
		draw_rect(Rect2(247, 135, 86 * spring_boost_timer / SPRING_BOOST_DURATION, 8), LIME)
	for index in MAX_HEALTH:
		var center := Vector2(VIEW_SIZE.x * 0.5 + (index - (MAX_HEALTH - 1) * 0.5) * 46, VIEW_SIZE.y - 43)
		var heart_color := RED if index < health else Color("405062")
		draw_circle(center + Vector2(-7, -4), 11, Color.BLACK)
		draw_circle(center + Vector2(7, -4), 11, Color.BLACK)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-18, -1), center + Vector2(18, -1), center + Vector2(0, 21)]), Color.BLACK)
		draw_circle(center + Vector2(-7, -4), 8, heart_color)
		draw_circle(center + Vector2(7, -4), 8, heart_color)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-15, -1), center + Vector2(15, -1), center + Vector2(0, 16)]), heart_color)


func draw_score_counter() -> void:
	# The run's existing height score, rendered as original bubble-letter numerals.
	var digits := str(maxi(0, int(height_meters)))
	var scale_value := minf(0.86, 420.0 / (float(digits.length()) * 76.0 + 14.0))
	var digit_size := Vector2(90, 126) * scale_value
	var advance := 76.0 * scale_value
	var total_width := advance * (digits.length() - 1) + digit_size.x
	var origin := Vector2((VIEW_SIZE.x - total_width) * 0.5, 14)
	for index in digits.length():
		var numeral := int(digits.substr(index, 1))
		draw_texture_rect_region(SCORE_DIGITS_TEX, Rect2(origin + Vector2(index * advance, 0), digit_size), Rect2(numeral * 90, 0, 90, 126))


func draw_tutorial() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0, 0, 0, 0.18))
	if tilt_control.uses_keyboard():
		draw_keyboard_help(735.0)
		return
	var phase := fmod(tutorial_time, 1.65) / 1.65
	var press := smoothstep(0.10, 0.40, phase) * (1.0 - smoothstep(0.52, 0.84, phase))
	var tap_point := Vector2(270, 849)
	var ripple := clampf((phase - 0.40) / 0.42, 0.0, 1.0)
	if phase >= 0.40 and phase < 0.82:
		var radius := lerpf(12.0, 42.0, ripple)
		var ring_color := Color(1, 1, 1, 1.0 - ripple)
		draw_arc(tap_point, radius, 0, TAU, 48, Color(0, 0, 0, ring_color.a * 0.8), 7, true)
		draw_arc(tap_point, radius, 0, TAU, 48, ring_color, 3, true)
	var hand_position := tap_point + Vector2(0, -12) * (1.0 - press)
	var hand_scale := Vector2(1.0 + press * 0.04, 1.0 - press * 0.06) * 0.34
	draw_set_transform(hand_position, 0.03 * (1.0 - press), hand_scale)
	# Keep the fingertip anchored to the tap while the glove gently compresses.
	draw_texture_rect(TAP_GLOVE_TEX, Rect2(-130, -347, 300, 352), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_pause() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0, 0, 0, 0.70))
	draw_panel(Rect2(75, 315, 390, 315), Color("071f38"), CYAN, 4, 14)
	draw_label("PAUSED", Vector2(75, 392), 42, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 390, 5)
	draw_panel(Rect2(120, 440, 300, 62), Color("2ab43d"), LIME, 3, 9)
	draw_label("RESUME", Vector2(120, 482), 23, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 300, 3)
	draw_panel(Rect2(120, 520, 300, 62), Color("0b3153"), CYAN, 3, 9)
	draw_label("HOME", Vector2(120, 562), 23, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 300, 3)


func draw_particles() -> void:
	for particle in particles:
		var alpha := clampf(float(particle["life"]) / float(particle["max_life"]), 0, 1)
		var color: Color = particle["color"]
		color.a = alpha
		var size: float = float(particle["size"])
		draw_rect(Rect2(particle["pos"] - Vector2(size, size) * 0.5, Vector2(size, size)), color)


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
	var rect := Rect2((540 - width) * 0.5, VIEW_SIZE.y - 154, width, 48)
	draw_panel(rect, Color(0.01, 0.07, 0.13, 0.95), GOLD, 3, 9)
	draw_label(toast_text, Vector2(rect.position.x, rect.position.y + 33), 17, WHITE, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)

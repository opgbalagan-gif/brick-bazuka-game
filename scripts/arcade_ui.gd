extends RefCounted

const METAL := preload("res://scripts/metal_panel.gd")
const ORANGE := Color("ff7a08")
const WHITE := Color("fff7e9")
const LIME := Color("b7f30c")
const REWARDS := preload("res://scripts/rewards.gd")
const FONT := preload("res://assets/fonts/RussoOne-Regular.ttf")

static func label(value: String, font_size: int = 20, color: Color = WHITE) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", Color("000000"))
	node.add_theme_constant_override("outline_size", 3)
	return node

static func panel(parent: Node, rect: Rect2, bright: bool = false) -> Control:
	var node := METAL.new()
	node.position = rect.position
	node.size = rect.size
	node.bright = bright
	parent.add_child(node)
	return node

static func button(value: String, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = value
	node.add_theme_font_override("font", FONT)
	node.custom_minimum_size = Vector2(0, 48)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.add_theme_font_size_override("font_size", 20)
	node.add_theme_color_override("font_color", WHITE)
	node.add_theme_color_override("font_outline_color", Color.BLACK)
	node.add_theme_constant_override("outline_size", 5)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0.44) if state == "disabled" else Color(1, 1, 1, 0.08) if state == "hover" else Color(0, 0, 0, 0.20) if state == "pressed" else Color.TRANSPARENT
		box.border_color = LIME if state == "focus" else Color.TRANSPARENT
		box.set_border_width_all(2)
		box.set_corner_radius_all(10)
		box.content_margin_left = 14
		box.content_margin_right = 14
		node.add_theme_stylebox_override(state, box)
	var background := METAL.new()
	background.bright = primary
	background.show_behind_parent = true
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.add_child(background)
	return node

static func texture_button(texture: Texture2D, hint: String) -> TextureButton:
	var node := TextureButton.new()
	node.texture_normal = texture
	node.ignore_texture_size = true
	node.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	node.tooltip_text = hint
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.pressed.connect(func(): node.modulate = Color.WHITE)
	node.button_down.connect(func(): node.modulate = Color("ffc274"))
	node.button_up.connect(func(): node.modulate = Color.WHITE)
	return node

static func image(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture = texture
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func artist_banner(parent: Node, rect: Rect2) -> Control:
	var banner := Control.new()
	banner.position = rect.position
	banner.size = rect.size
	parent.add_child(banner)
	panel(banner, Rect2(Vector2.ZERO, rect.size))
	image(banner, preload("res://assets/release-september/artist.png"), Rect2(10, 10, 74, rect.size.y - 20))
	var title := label("BRICK BAZUKA × SNWEED", 18)
	title.position = Vector2(94, 10)
	banner.add_child(title)
	var music := button("СЛУШАТЬ ТРЕКИ", true)
	music.position = Vector2(94, 39)
	music.size = Vector2(194, 44)
	music.custom_minimum_size.y = 44
	music.add_theme_font_size_override("font_size", 15)
	music.pressed.connect(func(): OS.shell_open(REWARDS.MUSIC_URL))
	banner.add_child(music)
	var shop := button("SNWEED.COM")
	shop.position = Vector2(298, 39)
	shop.size = Vector2(rect.size.x - 308, 44)
	shop.custom_minimum_size.y = 44
	shop.add_theme_font_size_override("font_size", 14)
	shop.pressed.connect(func(): OS.shell_open(REWARDS.SITE_URL))
	banner.add_child(shop)
	return banner

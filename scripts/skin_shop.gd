extends Control

signal closed
signal changed

const UI := preload("res://scripts/arcade_ui.gd")
const REWARDS := preload("res://scripts/rewards.gd")
var wallet
var balance: Label
var ticket_label: Label
var classic_button: Button
var prisoner_button: Button

func _ready() -> void:
	size = Vector2(540, 960)
	z_index = 25
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.87)
	dim.size = size
	add_child(dim)
	UI.panel(self, Rect2(18, 22, 504, 916))
	var title := UI.label("СКИНЫ", 34)
	title.position = Vector2(38, 40)
	add_child(title)
	balance = UI.label("", 24, UI.LIME)
	balance.position = Vector2(38, 90)
	add_child(balance)
	var hint := UI.label("Собирай кейсы на трассе и открывай образы.", 17)
	hint.position = Vector2(38, 126)
	add_child(hint)
	classic_button = _card(Rect2(38, 170, 222, 334), preload("res://assets/characters/main_hero.png"), "КЛАССИКА", "Уже твой", REWARDS.DEFAULT_SKIN)
	prisoner_button = _card(Rect2(280, 170, 222, 334), preload("res://assets/release-september/prisoner-preview.tres"), "ЗАКЛЮЧЁННЫЙ №13", "1 200 монет", REWARDS.ORANGE_SKIN)
	UI.panel(self, Rect2(38, 524, 464, 138))
	UI.image(self, preload("res://assets/release-september/locked-skin.tres"), Rect2(50, 536, 120, 114)).modulate = Color("78878d")
	var soon := UI.label("СЛЕДУЮЩИЙ СКИН\nСКОРО", 22, UI.ORANGE)
	soon.position = Vector2(188, 556)
	add_child(soon)
	UI.panel(self, Rect2(38, 682, 464, 122))
	UI.image(self, preload("res://assets/release-september/promo-safe.tres"), Rect2(50, 700, 78, 78))
	ticket_label = UI.label("", 19)
	ticket_label.position = Vector2(142, 698)
	ticket_label.size = Vector2(342, 96)
	ticket_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(ticket_label)
	var close := UI.button("ВЕРНУТЬСЯ", true)
	close.position = Vector2(38, 830)
	close.size = Vector2(464, 64)
	close.pressed.connect(func(): hide(); closed.emit())
	add_child(close)
	hide()

func _card(rect: Rect2, texture: Texture2D, title: String, price: String, id: String) -> Button:
	UI.panel(self, rect)
	UI.image(self, texture, Rect2(rect.position + Vector2(14, 16), Vector2(rect.size.x - 28, 204)))
	var caption := UI.label(title, 17)
	caption.position = rect.position + Vector2(8, 224)
	caption.size.x = rect.size.x - 16
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(caption)
	var cost := UI.label(price, 18, UI.ORANGE)
	cost.position = rect.position + Vector2(8, 249)
	cost.size.x = rect.size.x - 16
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(cost)
	var action := UI.button("ВЫБРАТЬ", true)
	action.position = rect.position + Vector2(12, 282)
	action.size = Vector2(rect.size.x - 24, 42)
	action.custom_minimum_size.y = 42
	action.add_theme_font_size_override("font_size", 17)
	action.pressed.connect(func():
		if wallet.select_skin(id):
			changed.emit()
		refresh())
	add_child(action)
	return action

func open() -> void:
	refresh()
	show()

func refresh() -> void:
	balance.text = "ТВОИ МОНЕТЫ: " + str(wallet.coins)
	classic_button.text = "НАДЕТО" if wallet.equipped == REWARDS.DEFAULT_SKIN else "НАДЕТЬ"
	classic_button.disabled = wallet.equipped == REWARDS.DEFAULT_SKIN
	if wallet.equipped == REWARDS.ORANGE_SKIN:
		prisoner_button.text = "НАДЕТО"
		prisoner_button.disabled = true
	elif REWARDS.ORANGE_SKIN in wallet.owned:
		prisoner_button.text = "НАДЕТЬ"
		prisoner_button.disabled = false
	else:
		prisoner_button.text = "КУПИТЬ" if wallet.coins >= REWARDS.SKIN_PRICE else "НУЖНО 1 200"
		prisoner_button.disabled = wallet.coins < REWARDS.SKIN_PRICE
	ticket_label.text = ("ПРОМОБИЛЕТОВ: " + str(wallet.promo_tickets) + "\n-5% SNWEED · акция скоро") if wallet.promo_tickets > 0 else "РЕДКИЙ СЕЙФ SNWEED\nНайди на трассе промобилет -5%. Акция скоро."

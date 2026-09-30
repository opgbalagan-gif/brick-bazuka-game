extends RefCounted

const CASE_VALUE := 100
const SKIN_PRICE := 1200
const SITE_URL := "https://snweed.com/"
const MUSIC_URL := "https://music.yandex.ru/artist/2191223"
const DEFAULT_SKIN := "classic"
const ORANGE_SKIN := "prisoner13"

var coins := 0
var owned: Array[String] = [DEFAULT_SKIN]
var equipped := DEFAULT_SKIN
var promo_tickets := 0

func load_from(config: ConfigFile) -> void:
	coins = maxi(0, int(config.get_value("rewards", "coins", 0)))
	promo_tickets = maxi(0, int(config.get_value("rewards", "promo_tickets", 0)))
	owned = [DEFAULT_SKIN]
	var saved = config.get_value("rewards", "owned_skins", [])
	if saved is Array and ORANGE_SKIN in saved:
		owned.append(ORANGE_SKIN)
	var choice := str(config.get_value("rewards", "equipped_skin", DEFAULT_SKIN))
	equipped = choice if choice in owned else DEFAULT_SKIN

func save_to(config: ConfigFile) -> void:
	config.set_value("rewards", "coins", coins)
	config.set_value("rewards", "owned_skins", owned)
	config.set_value("rewards", "equipped_skin", equipped)
	config.set_value("rewards", "promo_tickets", promo_tickets)

func collect_case() -> int:
	coins += CASE_VALUE
	return CASE_VALUE

func collect_safe() -> void:
	promo_tickets += 1

func select_skin(id: String) -> bool:
	if id not in [DEFAULT_SKIN, ORANGE_SKIN]:
		return false
	if id not in owned:
		if coins < SKIN_PRICE:
			return false
		coins -= SKIN_PRICE
		owned.append(id)
	equipped = id
	return true

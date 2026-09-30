extends Control

signal restart_requested
signal home_requested
signal player_name_changed(value: String)
signal browse_closed

const API_URL := "https://script.google.com/macros/s/AKfycbyCcXRUgh1DKEUjoNRJrtdAyuY8hMfE7y5l4k2Yqb7qTexvAc6HnRq5h-RP9B9UQWomMw/exec"
const WHITE := Color("f5f8ee")
const LIME := Color("b7f30c")
const UI := preload("res://scripts/arcade_ui.gd")

var api_url := API_URL
var last_name := ""
var run_id := ""
var run_token := ""
var run_score := 0
var submitted := false
var pending_score: Dictionary = {}
var busy := {"runs": false, "scores": false, "leaderboard": false}
var requests: Dictionary = {}
var reward_summary: Label
var score_label: Label
var name_input: LineEdit
var save_button: Button
var status_label: Label
var rows_box: VBoxContainer
var refresh_timer: Timer
var web_name_input: JavaScriptObject
var storage_path := "user://brick_rating_state.cfg"
var browsing := false
var editing_name := false
var title_label: Label
var edit_name_button: Button
var restart_button: Button
var home_button: Button
var close_button: Button
var board_status: Label
var cached_rows: Array = []
var cache_updated_at := ""
var pending_scores: Array = []
var sending_score: Dictionary = {}
var run_key := ""
var retry_after := {"runs": 0.0, "scores": 0.0, "leaderboard": 0.0, "queue_runs": 0.0}
var retry_count := {"runs": 0, "scores": 0, "leaderboard": 0, "queue_runs": 0}


func _ready() -> void:
	if OS.has_feature("web"):
		web_name_input = JavaScriptBridge.get_interface("BrickNameInput")
	size = Vector2(540, 960)
	z_index = 20
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_load_state()
	if web_name_input != null:
		var remembered := str(web_name_input.get_saved_name())
		if _valid_name(remembered):
			last_name = remembered
			player_name_changed.emit(last_name)
		elif _valid_name(last_name):
			web_name_input.save_name(last_name)
	for operation in ["runs", "scores", "leaderboard", "queue_runs"]:
		busy[operation] = false
		var request := HTTPRequest.new()
		request.timeout = 18.0
		request.max_redirects = 8
		request.request_completed.connect(_response.bind(operation))
		add_child(request)
		requests[operation] = request
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 15.0
	refresh_timer.timeout.connect(load_scores)
	add_child(refresh_timer)
	hide()


func _process(delta: float) -> void:
	if not api_url.is_empty():
		for operation in retry_after:
			if retry_after[operation] <= 0.0:
				continue
			retry_after[operation] = maxf(0, retry_after[operation] - delta)
			if retry_after[operation] == 0.0:
				if operation == "leaderboard" and visible:
					load_scores()
				elif operation == "runs" and not run_key.is_empty() and run_id.is_empty():
					_send("runs", {"action": "brick_runs"})
		_process_queue()
	if not visible or web_name_input == null:
		return
	var rect := name_input.get_global_rect()
	web_name_input.place(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
	web_name_input.set_editable(name_input.editable)
	var value := str(web_name_input.get_value())
	if name_input.text != value:
		name_input.text = value
		_name_changed(value)
	if bool(web_name_input.consume_submit()):
		commit_name()


func _exit_tree() -> void:
	if web_name_input != null:
		web_name_input.close()


func _box(fill: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style


func _label(text_value: String, font_size: int = 20, color: Color = WHITE) -> Label:
	var label := UI.label(text_value, font_size, color)
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text_value: String, primary: bool = false) -> Button:
	return UI.button(text_value, primary)


func _place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size
	add_child(node)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.83)
	dim.size = Vector2(540, 960)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	UI.panel(self, Rect2(16, 20, 508, 920))
	UI.panel(self, Rect2(30, 34, 480, 58), true)
	title_label = _label("ИГРА ОКОНЧЕНА", 29)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(title_label, Rect2(44, 42, 452, 42))
	score_label = _label("0 ОЧКОВ", 42, UI.ORANGE)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(score_label, Rect2(38, 104, 464, 54))
	reward_summary = _label("", 16, UI.LIME)
	reward_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(reward_summary, Rect2(38, 166, 464, 24))
	_place(_label("ТВОЁ ИМЯ", 17), Rect2(40, 201, 460, 26))
	name_input = LineEdit.new()
	name_input.placeholder_text = "Введи имя"
	name_input.max_length = 20
	name_input.virtual_keyboard_enabled = web_name_input == null
	name_input.add_theme_font_size_override("font_size", 22)
	name_input.add_theme_color_override("font_color", WHITE)
	name_input.add_theme_color_override("font_uneditable_color", WHITE)
	name_input.add_theme_stylebox_override("normal", _box(Color("0c1012"), UI.ORANGE, 3))
	name_input.add_theme_stylebox_override("read_only", _box(Color("0c1012"), UI.ORANGE, 3))
	name_input.add_theme_stylebox_override("focus", _box(Color("0c1012"), LIME, 3))
	name_input.text_changed.connect(_name_changed)
	name_input.text_submitted.connect(func(_text: String): commit_name())
	_place(name_input, Rect2(38, 230, 304, 50))
	edit_name_button = _button("ИЗМЕНИТЬ", true)
	edit_name_button.add_theme_font_size_override("font_size", 15)
	edit_name_button.pressed.connect(func():
		if editing_name:
			commit_name()
		else:
			editing_name = true
			_sync_profile()
			name_input.grab_focus())
	_place(edit_name_button, Rect2(352, 230, 150, 50))
	save_button = _button("СОХРАНИТЬ", true)
	save_button.add_theme_font_size_override("font_size", 26)
	save_button.pressed.connect(save_score)
	_place(save_button, Rect2(38, 292, 464, 58))
	status_label = _label("", 14, Color("c5cbd1"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(status_label, Rect2(40, 360, 460, 40))
	UI.panel(self, Rect2(30, 414, 480, 280))
	UI.panel(self, Rect2(38, 404, 320, 48), true)
	var board_title := _label("ОБЩИЙ РЕЙТИНГ", 23)
	board_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(board_title, Rect2(44, 412, 306, 32))
	var refresh := _button("ОБНОВИТЬ", true)
	refresh.add_theme_font_size_override("font_size", 14)
	refresh.pressed.connect(load_scores)
	_place(refresh, Rect2(368, 404, 134, 48))
	for spec in [["№", 48, 36], ["ИГРОК", 98, 276], ["ОЧКИ", 391, 103]]:
		var column := _label(spec[0], 16, UI.ORANGE)
		_place(column, Rect2(spec[1], 464, spec[2], 26))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(scroll, Rect2(44, 496, 452, 180))
	rows_box = VBoxContainer.new()
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 0)
	scroll.add_child(rows_box)
	board_status = _label("", 12, Color("c5cbd1"))
	board_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(board_status, Rect2(38, 700, 464, 32))
	UI.artist_banner(self, Rect2(30, 745, 480, 100))
	restart_button = _button("ЕЩЁ РАЗ", true)
	restart_button.add_theme_font_size_override("font_size", 23)
	restart_button.pressed.connect(func(): dismiss(); restart_requested.emit())
	_place(restart_button, Rect2(38, 864, 224, 54))
	home_button = _button("МЕНЮ", true)
	home_button.add_theme_font_size_override("font_size", 23)
	home_button.pressed.connect(func(): dismiss(); home_requested.emit())
	_place(home_button, Rect2(278, 864, 224, 54))
	close_button = _button("ВЕРНУТЬСЯ В ИГРУ", true)
	close_button.pressed.connect(func(): dismiss(); browse_closed.emit())
	_place(close_button, Rect2(38, 864, 464, 54))


func set_rewards_summary(earned: int, balance: int, tickets: int) -> void:
	reward_summary.text = "+" + str(earned) + " МОНЕТ ЗА ЗАБЕГ  •  ВСЕГО " + str(balance)
	if tickets > 0:
		reward_summary.text += "  •  БИЛЕТ -5%"


func start_run() -> void:
	dismiss()
	requests["runs"].cancel_request()
	busy["runs"] = false
	retry_after["runs"] = 0.0
	retry_count["runs"] = 0
	run_key = str(Time.get_unix_time_from_system()) + ":" + str(Time.get_ticks_usec())
	run_id = ""
	run_token = ""
	submitted = false
	pending_score = {}
	_send("runs", {"action": "brick_runs"})


func show_results(score: int) -> void:
	browsing = false
	run_score = score
	title_label.text = "ИГРА ОКОНЧЕНА"
	score_label.text = str(score) + " ОЧКОВ"
	status_label.text = "Имя запоминается на этом устройстве."
	_open()


func show_board() -> void:
	browsing = true
	title_label.text = "ОБЩИЙ РЕЙТИНГ"
	status_label.text = "Имя запоминается на этом устройстве."
	_open()


func _open() -> void:
	if web_name_input != null:
		var remembered := str(web_name_input.get_saved_name())
		if _valid_name(remembered) and remembered != last_name:
			last_name = remembered
			player_name_changed.emit(last_name)
	name_input.text = last_name
	editing_name = not _valid_name(last_name)
	score_label.visible = not browsing
	reward_summary.visible = not browsing
	save_button.visible = not browsing
	restart_button.visible = not browsing
	home_button.visible = not browsing
	close_button.visible = browsing
	_sync_profile()
	if not cache_updated_at.is_empty():
		_draw_rows(cached_rows)
		board_status.text = "Последняя загруженная таблица · обновляем…"
	show()
	if web_name_input != null:
		web_name_input.open(last_name, name_input.editable)
	elif name_input.editable:
		name_input.grab_focus.call_deferred()
	_sync_save_button()
	load_scores()
	refresh_timer.start()


func _sync_profile() -> void:
	name_input.editable = editing_name
	edit_name_button.text = "ГОТОВО" if editing_name else "ИЗМЕНИТЬ"
	if web_name_input != null:
		web_name_input.set_editable(editing_name)


func _name_changed(value: String) -> void:
	var chosen := value.strip_edges()
	if _valid_name(chosen) and chosen != last_name:
		last_name = chosen
		player_name_changed.emit(last_name)
		if web_name_input != null:
			web_name_input.save_name(last_name)
	_sync_save_button()


func commit_name() -> bool:
	if web_name_input != null and visible:
		name_input.text = str(web_name_input.get_value())
	if not _valid_name(name_input.text.strip_edges()):
		status_label.text = "Имя: 2–20 символов без служебных знаков."
		return false
	_name_changed(name_input.text)
	editing_name = false
	_sync_profile()
	name_input.release_focus()
	status_label.text = "Имя сохранено на этом устройстве."
	return true


func dismiss() -> void:
	if is_instance_valid(name_input) and visible:
		if web_name_input != null:
			name_input.text = str(web_name_input.get_value())
		_name_changed(name_input.text)
	if web_name_input != null:
		web_name_input.close()
	if is_instance_valid(name_input):
		name_input.release_focus()
	if is_instance_valid(refresh_timer):
		refresh_timer.stop()
	hide()


func _sync_save_button() -> void:
	save_button.disabled = submitted or not pending_score.is_empty()
	if submitted:
		save_button.text = "СОХРАНЕНО"
	elif not pending_score.is_empty():
		save_button.text = "ОСТАЛСЯ НА УСТРОЙСТВЕ" if pending_score.has("error") else "ЖДЁТ ОТПРАВКИ"
	else:
		save_button.text = "СОХРАНИТЬ"


func _valid_name(value: String) -> bool:
	if value.length() < 2 or value.length() > 20 or "=+@-'".contains(value.left(1)):
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		if code < 32 or code == 127 or code == 60 or code == 62 or (code >= 0x202a and code <= 0x202e) or (code >= 0x2066 and code <= 0x2069):
			return false
	return true


func save_score() -> void:
	if browsing or submitted or not pending_score.is_empty() or not commit_name():
		return
	pending_score = {"action": "brick_scores", "id": run_id, "token": run_token, "name": last_name, "score": run_score, "key": run_key}
	pending_scores.append(pending_score)
	_save_state()
	status_label.text = "Результат сохранён на устройстве и ждёт отправки."
	_process_queue()
	_sync_save_button()


func load_scores() -> void:
	if not visible or busy["leaderboard"]:
		return
	if rows_box.get_child_count() == 0:
		_board_message("Загрузка рейтинга…")
	_send("leaderboard")


func _load_state() -> void:
	var config := ConfigFile.new()
	if config.load(storage_path) == OK:
		cached_rows = config.get_value("board", "rows", [])
		cache_updated_at = config.get_value("board", "updated_at", "")
		pending_scores = config.get_value("queue", "scores", [])
	if cache_updated_at.is_empty() and FileAccess.file_exists("res://assets/data/leaderboard_snapshot.json"):
		var snapshot = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/leaderboard_snapshot.json"))
		if snapshot is Dictionary and snapshot.get("rows") is Array:
			cached_rows = snapshot["rows"]
			cache_updated_at = str(snapshot.get("updatedAt", ""))


func _save_state() -> void:
	var config := ConfigFile.new()
	config.set_value("board", "rows", cached_rows)
	config.set_value("board", "updated_at", cache_updated_at)
	config.set_value("queue", "scores", pending_scores)
	config.save(storage_path)


func _process_queue() -> void:
	if api_url.is_empty() or busy["scores"] or busy["queue_runs"] or retry_after["scores"] > 0 or retry_after["queue_runs"] > 0:
		return
	for entry in pending_scores:
		if entry.has("error"):
			continue
		if entry.get("id", "").is_empty() and entry.get("key", "") == run_key and busy["runs"]:
			return
		sending_score = entry
		if entry.get("id", "").is_empty():
			_send("queue_runs", {"action": "brick_runs"})
		else:
			var payload := {"action": "brick_scores", "id": entry["id"], "token": entry["token"], "name": entry["name"], "score": entry["score"]}
			_send("scores", payload)
		return


func _send(operation: String, payload: Dictionary = {}) -> void:
	if api_url.is_empty():
		_failed(operation, "Рейтинг отключён в этой проверке.")
		return
	busy[operation] = true
	var url := api_url + "?t=" + str(Time.get_ticks_msec())
	var method := HTTPClient.METHOD_GET
	var headers := PackedStringArray()
	var body := ""
	if payload.is_empty():
		url += "&action=brick_leaderboard"
	else:
		method = HTTPClient.METHOD_POST
		headers.append("Content-Type: text/plain;charset=UTF-8")
		body = JSON.stringify(payload)
	var error: Error = requests[operation].request(url, headers, method, body)
	if error != OK:
		_response(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), operation)


func _response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, operation: String) -> void:
	busy[operation] = false
	var parser := JSON.new()
	var parsed := parser.parse(body.get_string_from_utf8()) if not body.is_empty() else ERR_PARSE_ERROR
	var value = parser.data if parsed == OK else null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not value is Dictionary:
		_failed(operation, "Нет связи с рейтингом. Нажми «Повторить».")
		return
	if value.has("error"):
		if operation == "scores":
			var error_message := str(value["error"])
			if "истёк" in error_message or "подтвердить" in error_message or "уже сохранён" in error_message or "Имя:" in error_message:
				sending_score["error"] = error_message
				_save_state()
				status_label.text = error_message + " Результат остался на устройстве."
				_sync_save_button()
				return
		_failed(operation, str(value["error"]))
		return
	if value.get("game", "") != "brick-bazuka":
		_failed(operation, "Рейтинг BRICK BAZUKA пока недоступен.")
		return
	if operation in ["runs", "queue_runs"]:
		var new_id := str(value.get("id", ""))
		var new_token := str(value.get("token", ""))
		if new_id.is_empty() or new_token.is_empty():
			_failed(operation, "Не удалось подключить забег. Повтори попытку.")
			return
		if operation == "runs":
			run_id = new_id
			run_token = new_token
			if not pending_score.is_empty() and pending_score.get("id", "").is_empty() and not busy["queue_runs"]:
				pending_score["id"] = run_id
				pending_score["token"] = run_token
		else:
			sending_score["id"] = new_id
			sending_score["token"] = new_token
		_save_state()
	elif operation == "scores":
		if value.get("saved", false) != true:
			_failed(operation, "Сохранение не подтверждено. Повтори попытку.")
			return
		if sending_score.get("key", "") == run_key:
			submitted = true
			pending_score = {}
			status_label.text = "Результат в рейтинге. Твоё место: №" + str(int(value.get("rank", 0)))
		pending_scores.erase(sending_score)
		sending_score = {}
		_save_state()
		load_scores()
	elif operation == "leaderboard":
		if not value.get("rows") is Array:
			_failed(operation, "Не удалось загрузить рейтинг.")
			return
		cached_rows = value["rows"]
		cache_updated_at = str(value.get("updatedAt", Time.get_datetime_string_from_system(true)))
		_save_state()
		_draw_rows(cached_rows)
		board_status.text = "Обновлено · " + cache_updated_at.replace("T", " ").left(19) + " UTC"
	retry_count[operation] = 0
	retry_after[operation] = 0.0
	_sync_save_button()


func _failed(operation: String, message: String) -> void:
	busy[operation] = false
	if not api_url.is_empty():
		retry_count[operation] += 1
		retry_after[operation] = minf(30.0, pow(2.0, mini(retry_count[operation], 5)))
	if operation == "leaderboard":
		if not cache_updated_at.is_empty():
			_draw_rows(cached_rows)
			board_status.text = "Нет связи · последняя таблица от " + cache_updated_at.left(10) + ". Переподключаемся…"
		else:
			_board_message("Подключаемся к рейтингу…\nПовторяем запрос автоматически.")
	else:
		status_label.text = "Нет связи. Результат ждёт отправки; повторим автоматически." if not pending_scores.is_empty() else "Подключаемся автоматически. Имя сохранится и без сети."
	_sync_save_button()


func _clear_rows() -> void:
	for child in rows_box.get_children():
		rows_box.remove_child(child)
		child.queue_free()


func _board_message(message: String) -> void:
	_clear_rows()
	var label := _label(message, 19, Color("aec0cb"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows_box.add_child(label)


func _draw_rows(rows: Array) -> void:
	_clear_rows()
	if rows.is_empty():
		_board_message("Пока нет результатов.\nСтань первым!")
		return
	for entry in rows.slice(0, 10):
		if not entry is Dictionary:
			continue
		var line := HBoxContainer.new()
		line.custom_minimum_size.y = 36
		var rank := _label(str(int(entry.get("rank", 0))), 22, LIME if int(entry.get("rank", 0)) == 1 else UI.ORANGE)
		rank.custom_minimum_size.x = 38
		line.add_child(rank)
		var player := _label(str(entry.get("name", "")).left(20), 19)
		player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_child(player)
		var score := _label(str(int(entry.get("score", 0))), 19)
		score.custom_minimum_size.x = 100
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(score)
		rows_box.add_child(line)

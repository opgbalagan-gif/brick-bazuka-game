extends Control

signal restart_requested
signal home_requested
signal player_name_changed(value: String)

const API_URL := "https://script.google.com/macros/s/AKfycbyCcXRUgh1DKEUjoNRJrtdAyuY8hMfE7y5l4k2Yqb7qTexvAc6HnRq5h-RP9B9UQWomMw/exec"
const WHITE := Color("f5f8ee")
const LIME := Color("80df41")

var api_url := API_URL
var last_name := ""
var run_id := ""
var run_token := ""
var run_score := 0
var submitted := false
var pending_score: Dictionary = {}
var busy := {"runs": false, "scores": false, "leaderboard": false}
var requests: Dictionary = {}
var score_label: Label
var name_input: LineEdit
var save_button: Button
var status_label: Label
var rows_box: VBoxContainer
var refresh_timer: Timer
var web_name_input: JavaScriptObject


func _ready() -> void:
	if OS.has_feature("web"):
		web_name_input = JavaScriptBridge.get_interface("BrickNameInput")
	size = Vector2(540, 960)
	z_index = 20
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	for operation in ["runs", "scores", "leaderboard"]:
		var request := HTTPRequest.new()
		request.timeout = 40.0
		request.max_redirects = 8
		request.request_completed.connect(_response.bind(operation))
		add_child(request)
		requests[operation] = request
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 15.0
	refresh_timer.timeout.connect(load_scores)
	add_child(refresh_timer)
	hide()


func _process(_delta: float) -> void:
	if not visible or web_name_input == null:
		return
	var rect := name_input.get_global_rect()
	web_name_input.place(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
	web_name_input.set_editable(name_input.editable)
	var value := str(web_name_input.get_value())
	if name_input.text != value:
		name_input.text = value
		_sync_save_button()
	if bool(web_name_input.consume_submit()):
		save_score()


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
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text_value: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_stylebox_override("normal", _box(Color("287f29") if primary else Color("12334b"), LIME if primary else Color("355c70")))
	button.add_theme_stylebox_override("hover", _box(Color("366b36"), LIME))
	button.add_theme_stylebox_override("pressed", _box(Color("1b4e28"), LIME))
	button.add_theme_stylebox_override("disabled", _box(Color("1b303e"), Color("354751")))
	return button


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.76)
	dim.size = Vector2(540, 960)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(30, 64)
	panel.size = Vector2(480, 832)
	panel.add_theme_stylebox_override("panel", _box(Color("071f38"), LIME, 3))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var content := VBoxContainer.new()
	content.position = Vector2(54, 84)
	content.size = Vector2(432, 790)
	content.add_theme_constant_override("separation", 8)
	add_child(content)
	var title := _label("ЗАБЕГ ЗАВЕРШЁН", 27, Color("ff8a36"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	score_label = _label("0 ОЧКОВ", 36)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(score_label)
	content.add_child(_label("ТВОЁ ИМЯ", 13, Color("aec0cb")))
	var form := HBoxContainer.new()
	form.add_theme_constant_override("separation", 8)
	content.add_child(form)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Введи имя"
	name_input.max_length = 20
	name_input.custom_minimum_size = Vector2(245, 48)
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.virtual_keyboard_enabled = web_name_input == null
	name_input.add_theme_font_size_override("font_size", 22)
	name_input.add_theme_color_override("font_color", WHITE)
	name_input.add_theme_stylebox_override("normal", _box(Color("061420"), Color("557181")))
	name_input.add_theme_stylebox_override("focus", _box(Color("061420"), LIME))
	name_input.text_changed.connect(func(_text: String): _sync_save_button())
	name_input.text_submitted.connect(func(_text: String): save_score())
	form.add_child(name_input)
	save_button = _button("СОХРАНИТЬ", true)
	save_button.custom_minimum_size.x = 166
	save_button.pressed.connect(save_score)
	form.add_child(save_button)
	status_label = _label("", 14, Color("aec0cb"))
	status_label.custom_minimum_size.y = 38
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(status_label)
	var heading := HBoxContainer.new()
	var board_title := _label("ОБЩИЙ РЕЙТИНГ", 22)
	board_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(board_title)
	var refresh := _button("ОБНОВИТЬ")
	refresh.add_theme_font_size_override("font_size", 12)
	refresh.custom_minimum_size = Vector2(100, 32)
	refresh.pressed.connect(load_scores)
	heading.add_child(refresh)
	content.add_child(heading)
	var columns := HBoxContainer.new()
	for spec in [["№", 38], ["ИГРОК", 284], ["ОЧКИ", 100]]:
		var column := _label(spec[0], 12, Color("829dac"))
		column.custom_minimum_size.x = spec[1]
		columns.add_child(column)
	content.add_child(columns)
	rows_box = VBoxContainer.new()
	rows_box.custom_minimum_size.y = 320
	rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 3)
	content.add_child(rows_box)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 10)
	var restart := _button("ЕЩЁ РАЗ", true)
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart.custom_minimum_size.y = 54
	restart.pressed.connect(func(): dismiss(); restart_requested.emit())
	navigation.add_child(restart)
	var home := _button("МЕНЮ")
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.pressed.connect(func(): dismiss(); home_requested.emit())
	navigation.add_child(home)
	content.add_child(navigation)


func start_run() -> void:
	dismiss()
	for operation in requests:
		requests[operation].cancel_request()
		busy[operation] = false
	run_id = ""
	run_token = ""
	submitted = false
	pending_score = {}
	_send("runs", {"action": "brick_runs"})


func show_results(score: int) -> void:
	run_score = score
	score_label.text = str(score) + " ОЧКОВ"
	name_input.text = last_name
	name_input.editable = pending_score.is_empty() and not submitted
	status_label.text = "Введи имя, чтобы добавить результат."
	if run_id.is_empty():
		status_label.text = "Подключение к рейтингу…" if busy["runs"] else "Нет связи с рейтингом. Нажми «Повторить»."
	show()
	if web_name_input != null:
		web_name_input.open(last_name, name_input.editable)
	elif name_input.editable:
		name_input.grab_focus.call_deferred()
	_sync_save_button()
	load_scores()
	refresh_timer.start()


func dismiss() -> void:
	if web_name_input != null:
		web_name_input.close()
	if is_instance_valid(name_input):
		name_input.release_focus()
	if is_instance_valid(refresh_timer):
		refresh_timer.stop()
	hide()


func _sync_save_button() -> void:
	save_button.disabled = submitted or busy["scores"] or busy["runs"]
	if submitted:
		save_button.text = "СОХРАНЕНО"
	elif busy["scores"]:
		save_button.text = "ОТПРАВКА…"
	elif busy["runs"]:
		save_button.text = "ПОДКЛЮЧЕНИЕ…"
	elif run_id.is_empty() or not pending_score.is_empty():
		save_button.text = "ПОВТОРИТЬ"
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
	if web_name_input != null and visible:
		name_input.text = str(web_name_input.get_value())
	if submitted or busy["scores"] or busy["runs"]:
		return
	if run_id.is_empty():
		status_label.text = "Подключение к рейтингу…"
		_send("runs", {"action": "brick_runs"})
		_sync_save_button()
		return
	if pending_score.is_empty():
		var chosen_name := name_input.text.strip_edges()
		if not _valid_name(chosen_name):
			status_label.text = "Имя: 2–20 символов без служебных знаков."
			name_input.grab_focus()
			return
		last_name = chosen_name
		player_name_changed.emit(last_name)
		pending_score = {"action": "brick_scores", "id": run_id, "token": run_token, "name": chosen_name, "score": run_score}
	name_input.editable = false
	if web_name_input != null:
		web_name_input.set_editable(false)
	name_input.release_focus()
	status_label.text = "Сохраняем результат…"
	_send("scores", pending_score)
	_sync_save_button()


func load_scores() -> void:
	if not visible or busy["leaderboard"]:
		return
	if rows_box.get_child_count() == 0:
		_board_message("Загрузка рейтинга…")
	_send("leaderboard")


func _send(operation: String, payload: Dictionary = {}) -> void:
	if api_url.is_empty():
		_failed(operation, "Рейтинг отключён в этой проверке.")
		return
	busy[operation] = true
	var url := api_url
	var method := HTTPClient.METHOD_GET
	var headers := PackedStringArray()
	var body := ""
	if payload.is_empty():
		url += "?action=brick_leaderboard"
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
			pending_score = {}
			name_input.editable = true
		_failed(operation, str(value["error"]))
		return
	if value.get("game", "") != "brick-bazuka":
		_failed(operation, "Рейтинг BRICK BAZUKA пока недоступен.")
		return
	if operation == "runs":
		run_id = str(value.get("id", ""))
		run_token = str(value.get("token", ""))
		if run_id.is_empty() or run_token.is_empty():
			_failed(operation, "Не удалось подключить забег. Повтори попытку.")
			return
		status_label.text = "Введи имя, чтобы добавить результат."
	elif operation == "scores":
		if value.get("saved", false) != true:
			_failed(operation, "Сохранение не подтверждено. Повтори попытку.")
			return
		submitted = true
		status_label.text = "Твоё место: №" + str(int(value.get("rank", 0)))
		load_scores()
	elif operation == "leaderboard":
		if not value.get("rows") is Array:
			_failed(operation, "Не удалось загрузить рейтинг.")
			return
		_draw_rows(value["rows"])
	_sync_save_button()


func _failed(operation: String, message: String) -> void:
	if operation == "leaderboard":
		if rows_box.get_child_count() <= 1:
			_board_message("Рейтинг недоступен.\nНажми «Обновить».")
	else:
		status_label.text = message
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
		line.custom_minimum_size.y = 28
		var rank := _label(str(int(entry.get("rank", 0))), 18, LIME)
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

extends SceneTree

class MockBoard extends "res://scripts/leaderboard.gd":
	var sent: Array = []
	func _send(operation: String, payload: Dictionary = {}) -> void:
		busy[operation] = true
		sent.append({"operation": operation, "payload": payload.duplicate(true)})

func _init() -> void:
	run.call_deferred()

func response(board, operation: String, value: Dictionary) -> void:
	board._response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(value).to_utf8_buffer(), operation)

func run() -> void:
	var path := "user://rating_reliability_test.cfg"
	DirAccess.remove_absolute(path)
	var board := MockBoard.new()
	board.storage_path = path
	root.add_child(board)
	board.set_process(false)
	board.last_name = ""
	board.start_run()
	board.show_results(123)
	board.name_input.text = "Игрок 42"
	board._name_changed(board.name_input.text)
	assert(board.last_name == "Игрок 42", "Name must be remembered before any network response or score submission")
	assert(board.commit_name() and not board.name_input.editable and board.edit_name_button.text == "ИЗМЕНИТЬ", "Saved name must be read-only beside an explicit change button")
	board.edit_name_button.pressed.emit()
	assert(board.name_input.editable, "Change must re-enable the name field")
	board.commit_name()
	response(board, "runs", {"game": "brick-bazuka", "id": "run-one", "token": "token-one"})
	board.save_score()
	assert(board.pending_scores.size() == 1 and not board.submitted, "Submission must persist until the server confirms it")
	var first_payload: Dictionary = board.sent.back()["payload"].duplicate(true)
	board._response(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), "scores")
	assert(board.retry_after["scores"] > 0 and board.pending_scores.size() == 1, "A network failure must schedule retry without losing the score")
	var restored := MockBoard.new()
	root.add_child(restored)
	restored.storage_path = path
	restored._load_state()
	assert(restored.pending_scores.size() == 1 and restored.pending_scores[0]["score"] == 123, "Queued scores must survive closing and reopening the game")
	restored.free()
	board._process(2.1)
	assert(board.sent.back()["operation"] == "scores" and board.sent.back()["payload"] == first_payload, "Retries must send the same run and score to prevent duplicates")
	board.start_run()
	assert(board.pending_scores.size() == 1, "Starting another game must preserve an unconfirmed result")
	response(board, "scores", {"game": "brick-bazuka", "saved": true, "rank": 3})
	assert(board.pending_scores.is_empty() and not board.submitted, "An old result confirmation must not mark the new run submitted")
	board.show_board()
	response(board, "leaderboard", {"game": "brick-bazuka", "rows": [{"rank": 1, "name": "Игрок", "score": 500}], "updatedAt": "2026-09-25T12:00:00Z"})
	board._response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "<html>Temporary error</html>".to_utf8_buffer(), "leaderboard")
	assert(board.cached_rows.size() == 1 and board.rows_box.get_child_count() == 1 and "Нет связи" in board.board_status.text, "Temporary HTML responses must keep the last real leaderboard and mark it offline")
	assert(board.browsing and not board.save_button.visible and board.close_button.visible, "Browsing the leaderboard must not create a score")
	board.dismiss()
	board.show_results(50)
	assert(board.name_input.text == "Игрок 42" and not board.name_input.editable, "Future runs must reuse the remembered name")
	board.free()
	DirAccess.remove_absolute(path)
	print("RATING_RELIABILITY_TEST_OK offline_name edit cache retry identical_payload durable_queue restart browse")
	quit()

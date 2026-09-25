extends Node

signal shot_requested

const HOLD_TIME := 0.18
const DRAG_THRESHOLD := 12.0
const FULL_DRAG := 64.0
const SCREEN_CENTER := 270.0

var touches: Dictionary = {}
var primary_id := -1
var axis := 0.0


func reset() -> void:
	touches.clear()
	primary_id = -1
	axis = 0.0


func handle_event(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pointer := InputEventScreenTouch.new()
		pointer.index = 10000
		pointer.position = event.position
		pointer.pressed = event.pressed
		handle_event(pointer)
		return
	if event is InputEventMouseMotion and touches.has(10000):
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			touches.erase(10000)
			primary_id = -1 if touches.is_empty() else int(touches.keys()[0])
			update_axis()
			return
		var pointer := InputEventScreenDrag.new()
		pointer.index = 10000
		pointer.position = event.position
		handle_event(pointer)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = {"origin": event.position, "pos": event.position, "age": 0.0, "drag": false, "held": false}
			if primary_id == -1:
				primary_id = event.index
		elif touches.has(event.index):
			var touch: Dictionary = touches[event.index]
			var is_tap: bool = not event.canceled and not touch["drag"] and not touch["held"] and event.position.distance_to(touch["origin"]) < DRAG_THRESHOLD
			touches.erase(event.index)
			if primary_id == event.index:
				primary_id = -1 if touches.is_empty() else int(touches.keys()[0])
			update_axis()
			if is_tap:
				shot_requested.emit()
	elif event is InputEventScreenDrag and touches.has(event.index):
		var touch: Dictionary = touches[event.index]
		touch["pos"] = event.position
		if event.position.distance_to(touch["origin"]) >= DRAG_THRESHOLD:
			touch["drag"] = true
		update_axis()


func advance(delta: float) -> void:
	for touch in touches.values():
		touch["age"] += delta
		if touch["age"] >= HOLD_TIME:
			touch["held"] = true
	update_axis()


func is_steering() -> bool:
	return touches.has(primary_id) and (touches[primary_id]["drag"] or touches[primary_id]["held"])


func update_axis() -> void:
	axis = 0.0
	if not touches.has(primary_id):
		return
	var touch: Dictionary = touches[primary_id]
	if touch["drag"]:
		var distance: float = touch["pos"].x - touch["origin"].x
		axis = signf(distance) * clampf((absf(distance) - 8.0) / (FULL_DRAG - 8.0), 0.0, 1.0)
	elif touch["held"]:
		var distance: float = touch["pos"].x - SCREEN_CENTER
		axis = signf(distance) if absf(distance) > 24.0 else 0.0

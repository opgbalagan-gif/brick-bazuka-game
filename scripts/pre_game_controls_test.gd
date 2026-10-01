extends SceneTree
func _init() -> void:
 run.call_deferred()
func tap(control: Control) -> void:
 for down in [true, false]:
  var event := InputEventScreenTouch.new()
  event.position = control.get_global_rect().get_center()
  event.pressed = down
  root.push_input(event, true)
  await process_frame
func run() -> void:
 var game = load("res://scenes/main.tscn").instantiate()
 game.profile_path = "user://pregame_test.cfg"
 root.add_child(game)
 game.leaderboard.api_url = ""
 game.set_process(false)
 game.handle_menu_press(game.cta_rect.get_center())
 var choice = game.pre_game_controls
 assert(choice.visible and game.screen == game.Screen.MENU)
 await tap(choice.tilt_button)
 assert(game.control_mode == "tilt" and not game.tilt_control.active)
 await tap(choice.back_button)
 assert(not choice.visible and game.screen == game.Screen.MENU)
 game.open_pre_game_controls()
 assert(game.control_mode == "tilt")
 await tap(choice.swipe_button)
 assert(game.control_mode == "touch")
 await tap(choice.play_button)
 assert(game.screen == game.Screen.GAME and not choice.visible and game.rockets.is_empty())
 game.open_pause()
 assert(game.pause_menu.visible)
 game.free()
 DirAccess.remove_absolute("user://pregame_test.cfg")
 print("PRE_GAME_TEST_OK choice back remembered_selection no_sensor_before_play no_extra_shot pause")
 quit()

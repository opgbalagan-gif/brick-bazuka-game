extends SceneTree

const WALLET := preload("res://scripts/rewards.gd")

func _init() -> void:
	run.call_deferred()

func run() -> void:
	var path := "user://rewards_test.cfg"
	DirAccess.remove_absolute(path)
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = path
	root.add_child(game)
	game.leaderboard.api_url = ""
	game.set_process(false)
	game.start_game()
	game.tutorial_visible = false
	assert(game.rewards.coins == 0 and not game.rewards.select_skin(WALLET.ORANGE_SKIN), "A new player must not be able to spend money they do not have")
	game.blocks = [{"pos": Vector2(220, 620), "size": Vector2(150, 50), "reward": "case"}]
	game.player_pos = Vector2(290, 584)
	game.previous_player_pos = game.player_pos
	game.check_reward_pickups()
	assert(game.rewards.coins == 100 and game.run_coins == 100 and game.blocks[0]["reward"] == "", "Collecting one case must credit 100 coins and consume the pickup")
	game.check_reward_pickups()
	assert(game.rewards.coins == 100, "Remaining on the same platform must not credit the case twice")
	game.blocks[0]["reward"] = "safe"
	game.check_reward_pickups()
	assert(game.rewards.promo_tickets == 1 and game.rewards.coins == 100 and game.reward_flights.back()["kind"] == "safe", "A safe must release a promo ticket instead of money")
	game.check_reward_pickups()
	assert(game.rewards.promo_tickets == 1, "A safe must not be collected twice")
	for index in 11:
		game.rewards.collect_case()
	assert(game.rewards.select_skin(WALLET.ORANGE_SKIN) and game.rewards.coins == 0, "Twelve cases must afford the orange skin")
	assert(game.rewards.select_skin(WALLET.ORANGE_SKIN) and game.rewards.coins == 0, "Re-equipping an owned skin must be free")
	assert(not game.rewards.select_skin("future_skin") and game.rewards.equipped == WALLET.ORANGE_SKIN, "The silhouette must not be purchasable without a real skin")
	game.save_profile()
	var config := ConfigFile.new()
	assert(config.load(path) == OK)
	var restored := WALLET.new()
	restored.load_from(config)
	assert(restored.coins == 0 and restored.promo_tickets == 1 and restored.equipped == WALLET.ORANGE_SKIN and WALLET.ORANGE_SKIN in restored.owned, "Balance, tickets, ownership and selection must survive reload")
	game.start_game()
	assert(game.run_coins == 0 and game.rewards.equipped == WALLET.ORANGE_SKIN and game.rewards.promo_tickets == 1, "Restart must preserve purchases and tickets but reset the run tally")
	# Pickups cannot be skipped during high-speed jet flight.
	game.blocks = [{"pos": Vector2(220, 620), "size": Vector2(150, 50), "reward": "case"}]
	game.previous_player_pos = Vector2(290, 750)
	game.player_pos = Vector2(290, 380)
	game.check_reward_pickups()
	assert(game.rewards.coins == 100, "A swept pickup must catch a case passed during jet flight")
	game.blocks.clear()
	game.rng.seed = 7302026
	var cases := 0
	var safes := 0
	var first_safe := -1
	for index in 500:
		game.spawn_block(-float(index) * 280)
		for block in game.blocks:
			var kind: String = block.get("reward", "")
			if kind.is_empty():
				continue
			assert(not block.get("fake", false) and not block.get("spring", false) and not block.get("boots", false), "Rewards must occupy real platforms and leave other pickups clear")
			if kind == "safe":
				safes += 1
				if first_safe < 0:
					first_safe = index
			else:
				cases += 1
		game.blocks.clear()
	assert(first_safe >= 60 and safes >= 3 and safes <= 8 and cases > safes * 6, "Safes must be much rarer than cash cases, with no early safe")
	game.tutorial_visible = false
	game.open_skin_shop()
	assert(game.paused and game.skin_shop.visible, "Opening skins during play must pause the run")
	game.skin_shop.hide()
	game.close_skin_shop()
	assert(not game.paused, "Closing skins must resume the previous run")
	game.paused = true
	game.open_skin_shop()
	game.skin_shop.hide()
	game.close_skin_shop()
	assert(game.paused, "Closing skins must preserve a pre-existing pause")
	game.leaderboard.show_results(3834)
	game.leaderboard.set_rewards_summary(200, 1300, 1)
	assert("200" in game.leaderboard.reward_summary.text and "1300" in game.leaderboard.reward_summary.text, "The results screen must show earned and total coins")
	game.free()
	DirAccess.remove_absolute(path)
	print("REWARDS_TEST_OK single_collection case100 rare_safe ticket_animation purchase1200 owned_free durable_save restart swept_jet shop_pause result_summary")
	quit()

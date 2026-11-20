extends SceneTree
const Leaderboard = preload("res://src/leaderboard.gd")
var failures := 0
var checks := 0
var game: Node3D
var performance: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func screenshot(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://docs/proof/phase-4/" + filename)
	check(error == OK, "screenshot " + filename)

func start() -> void:
	# Do not capture the user's pointer during unattended verification.
	game.capture_path = "test-no-pointer-capture"
	game._start_game()
	game.capture_path = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func capture_landscape(eye: Vector3, focus: Vector3) -> void:
	var original: Transform3D = game.camera.global_transform
	game.paused = true
	game.hud.hide()
	game.camera.global_position = eye
	game.camera.look_at(focus)
	await screenshot("landscape-%d.png" % game.sim.night)
	game.camera.global_transform = original
	game.hud.show()
	game.paused = false

func frames(number: int) -> void:
	for i in range(number):
		await physics_frame
		await process_frame

func measure_night() -> void:
	var start_ms := Time.get_ticks_msec()
	var count := 0
	while Time.get_ticks_msec() - start_ms < 2000:
		await RenderingServer.frame_post_draw
		count += 1
	var elapsed := Time.get_ticks_msec() - start_ms
	var fps := count * 1000.0 / elapsed
	performance.append({"night": game.sim.night, "frames": count, "milliseconds": elapsed, "average_fps": fps})
	check(fps >= 30, "average FPS on night %d: %.1f" % [game.sim.night, fps])

func run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	game.settings_path = "res://.tools/phase4-gui-test.cfg"
	game.leaderboard = Leaderboard.new("res://.tools/phase4-gui-ranking.json")
	root.add_child(game)
	await frames(3)
	check(game.menu.visible and not game.active, "menu shown before play")
	await screenshot("menu.png")
	start()
	await frames(2)
	check(game.active and not game.menu.visible, "start enters gameplay")
	Input.action_press("forward")
	Input.action_press("jump")
	await frames(12)
	check(game.sim.player.pos.z < -0.5, "W input moves in 3D game")
	check(game.sim.player.pos.y > 0, "Space input jumps in 3D game")
	Input.action_release("forward")
	Input.action_release("jump")
	await screenshot("gameplay.png")
	await measure_night()
	game.start_scenario = {"time_left_s": 45, "random_motes": false, "random_shades": false,
		"motes": [[-1, 0, -4]],
		"lanterns": [{"id": "L1", "pos": [-3.8, 0, -7.6], "lit": true},
			{"id": "L2", "pos": [0, 0, -8.5], "lit": true}, {"id": "L3", "pos": [3.8, 0, -7.6], "lit": true}]}
	start()
	await frames(2)
	var firefly := "M1"
	var first: Vector3 = game.mote_nodes[firefly].position
	var anchor: Vector3 = game.sim.motes[0].pos
	game.visual_time += 1.3
	game._sync_visuals(0.0)
	check(game.mote_nodes[firefly].position.distance_to(first) > 0.2 and game.sim.motes[0].pos == anchor,
		"firefly flies without moving the pickup anchor")
	check([game.lantern_nodes.L1.style, game.lantern_nodes.L2.style, game.lantern_nodes.L3.style] == [0, 1, 2],
		"visual scene includes all three lantern designs")
	var art_camera: Camera3D = game.camera
	game.pitch = 0.17
	game._update_camera(true)
	await screenshot("lanterns.png")
	await capture_landscape(Vector3(-6.8, 2.0, -2.0), Vector3(-5.2, 2.05, -13.5))
	game.paused = true
	art_camera.position = Vector3(1.45, 1.75, -4.7)
	art_camera.look_at(Vector3(0, 1.1, 0))
	await screenshot("may.png")
	game.paused = false
	game.start_scenario = {"time_left_s": 20, "random_motes": false, "random_shades": false,
		"lanterns": [{"id": "L1", "pos": [2, 0, -7], "lit": true, "fuel": 24},
			{"id": "L2", "pos": [-3, 0, -7], "ever_lit": true}],
		"shades": [{"id": "S1", "pos": [0, 0, -5], "state": "spawning", "state_ticks_left": 160}]}
	start()
	await frames(2)
	check(game.lantern_nodes.L1.bar.visible and not game.lantern_nodes.L1.ring.visible, "low fuel has a visible gauge without safety")
	check(game.lantern_nodes.L2.tear.visible and is_equal_approx(game.lantern_nodes.L2.shell.scale.y, 0.8), "dark lantern is torn and collapsed")
	var palette: StandardMaterial3D = game.shade_nodes.S1.accent
	game._set_accessible_palette(false)
	await frames(1)
	check(palette.albedo_color.is_equal_approx(Color("7A3CFF")), "normal shade accent")
	await screenshot("fuel.png")
	game._set_accessible_palette(true)
	game.accessible_palette = false
	game.settings = ConfigFile.new()
	game._load_settings()
	await screenshot("accessible.png")
	check(game.accessible_palette and palette.albedo_color.is_equal_approx(Color("00B3FF")), "saved palette reloads and recolors shade")
	check(game.timer_label.text.begins_with("⚠") and game._warning_color() == Color.WHITE, "warning uses a symbol and white")
	var event := InputEventAction.new()
	event.action = "pause"
	event.pressed = true
	game._unhandled_input(event)
	var tick: int = game.sim.tick
	await frames(4)
	check(game.paused and game.pause_screen.visible and game.sim.tick == tick, "Escape freezes simulation")
	game._open_settings()
	game.keys_screen.show()
	game._request_key("jump")
	var press := InputEventKey.new()
	press.pressed = true
	press.physical_keycode = KEY_W
	Input.parse_input_event(press)
	await frames(2)
	check(game.key_bindings.jump == KEY_SPACE and not game.rebind_action.is_empty(), "duplicate key rejected")
	press.physical_keycode = KEY_J
	Input.parse_input_event(press)
	await frames(2)
	check(game.key_bindings.jump == KEY_J and game.rebind_action.is_empty(), "unique key saved")
	game.key_bindings.jump = KEY_SPACE
	game.settings = ConfigFile.new()
	game._load_settings()
	check(game.key_bindings.jump == KEY_J, "bind reloads from disk")
	game._reset_keys()
	check(game.key_bindings.jump == KEY_SPACE, "defaults restore")
	game._close_keys()
	game._set_large_text(true)
	check(game.hint_label.get_theme_font_size("font_size") >= 22, "large text enabled")
	game._set_reduced_motion(true)
	check(game.reduced_motion, "reduced motion enabled")
	await screenshot("settings.png")
	game._set_large_text(false)
	game._set_reduced_motion(false)
	game.settings_screen.hide()
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(2)
	check(not game.paused and game.sim.tick > tick, "resume unfreezes simulation")
	game.start_scenario = JSON.parse_string(FileAccess.get_file_as_string("res://tests/scenarios/dawn_win.json"))
	start()
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	check(game.sim.state == "won" and game.end_screen.visible, "winning opens result screen")
	await screenshot("won.png")
	var first_score: int = game.campaign_score
	game._next_night()
	check(game.intro_screen.visible and game.campaign_night == 2, "winning night one leads to night two intro")
	start()
	await frames(2)
	check(game.sim.night == 2 and game.lantern_nodes.size() == 6, "night two builds six lanterns")
	await screenshot("night-2.png")
	await capture_landscape(Vector3(5, 2.1, 15), Vector3(14, 2.1, 7))
	await measure_night()
	game.start_scenario = {"random_motes": false, "random_shades": false, "random_drifters": false, "time_left_s": 0.01,
		"lanterns": [{"id": "L1", "lit": true}, {"id": "L2", "lit": true}, {"id": "L3", "lit": true},
			{"id": "L4", "lit": true}, {"id": "L5", "lit": true}, {"id": "L6", "lit": true}]}
	start()
	await frames(2)
	check(game.sim.state == "won" and game.campaign_score > first_score, "second win adds to campaign score")
	game._next_night()
	start()
	await frames(2)
	check(game.sim.night == 3 and game.lantern_nodes.size() == 7, "night three builds seven lanterns")
	await screenshot("night-3.png")
	await capture_landscape(Vector3(16, 6.4, 22), Vector3(6, 5.3, 14))
	await measure_night()
	game.start_scenario = {"random_motes": false, "random_shades": false, "random_drifters": false, "time_left_s": 0.01,
		"lanterns": [{"id": "L1", "lit": true}, {"id": "L2", "lit": true}, {"id": "L3", "lit": true},
			{"id": "L4", "lit": true}, {"id": "L5", "lit": true}, {"id": "L6", "lit": true}, {"id": "L7", "lit": true}]}
	start()
	await frames(2)
	check(game.end_title.text == "Bình Minh" and not game.next_button.visible, "third win shows dawn")
	check(game.score_form.visible, "dawn offers to save score")
	await screenshot("dawn.png")
	game.start_scenario = {"random_motes": false, "random_shades": false,
		"player": {"flames": 1}, "shades": [{"pos": [0, 0, 0]}]}
	start()
	await frames(2)
	check(game.sim.state == "lost" and game.end_screen.visible, "losing opens result screen")
	game.score_name.text = "!"
	game._save_score()
	check(not game.score_button.disabled and game.leaderboard.entries().is_empty(), "invalid name is rejected")
	game.score_name.text = "May_01"
	game._save_score()
	var ranking: Array = game.leaderboard.entries()
	check(ranking.size() == 1 and ranking[0].name == "May_01" and ranking[0].nights_won == 2, "game saves campaign result")
	await screenshot("lost.png")
	game.start_scenario = {}
	start()
	check(game.sim.state == "playing" and game.sim.player.flames == 3 and game.sim.score == 0 and game.sim.tick == 0, "restart resets state")
	game._return_menu()
	check(game.menu.visible and not game.active, "return to main menu")
	game._show_leaderboard()
	check(game.leaderboard_rows.text.contains("May_01"), "leaderboard screen shows result")
	await screenshot("leaderboard.png")
	game.leaderboard_screen.hide()
	game.capture_path = "test-no-pointer-capture"
	game._begin_exploration()
	game.capture_path = ""
	await screenshot("exploration.png")
	var first_layout: Array = game.sim.snapshot().lanterns
	check(game.sim.exploration and game.sim.island_radius == 60 and game.sim._has_floor(Vector3(52, 0, 0)), "exploration uses wider playable terrain")
	game.capture_path = "test-no-pointer-capture"
	game._begin_exploration()
	game.capture_path = ""
	check(game.sim.snapshot().lanterns != first_layout, "new exploration randomizes lamp coordinates")
	game._begin_campaign()
	start()
	check(not game.sim.exploration and game.sim.lanterns[0].pos == Vector3(0, 0, 25), "campaign restores the standard lantern layout")
	var file := FileAccess.open("res://docs/proof/phase-4/gui-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"gui_checks": checks, "failures": failures, "renderer": RenderingServer.get_video_adapter_name(),
		"viewport": [root.size.x, root.size.y], "performance": performance}, "  "))
	file.close()
	print("GUI checks: %d; failures: %d" % [checks, failures])
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("res://.tools/phase4-gui-test.cfg")
	DirAccess.remove_absolute("res://.tools/phase4-gui-ranking.json")
	quit(1 if failures else 0)

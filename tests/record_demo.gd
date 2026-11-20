extends SceneTree

var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func hold_frames(count: int) -> void:
	for i in count:
		await RenderingServer.frame_post_draw

func report(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://docs/proof/phase-4/" + name))

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await hold_frames(48)
	game.start_scenario = {"player": {"carried": 10}, "random_shades": false, "random_motes": false,
		"motes": [[-1, 0, -1.6], [2, 0, -6]],
		"lanterns": [{"id": "L1", "pos": [-3.8, 0, -7.6], "lit": true},
			{"id": "L2", "pos": [0, 0, -8.5]}, {"id": "L3", "pos": [3.8, 0, -7.6], "lit": true, "fuel": 24}]}
	game.capture_path = "demo-no-mouse-lock"
	game._start_game()
	game.capture_path = ""
	await hold_frames(76)
	Input.action_press("forward")
	while game.sim.nearest_lantern().is_empty() and game.sim.sim_tick < 350:
		await physics_frame
	Input.action_release("forward")
	Input.action_press("interact")
	await hold_frames(6)
	Input.action_release("interact")
	await hold_frames(100)
	game.paused = true
	var test := report("test-report.json")
	var benchmark := report("bench.json")
	var soak := report("soak.json")
	var rows := FileAccess.get_file_as_string("res://docs/proof/phase-4/win.jsonl").strip_edges().split("\n")
	var outcome: Dictionary = JSON.parse_string(rows[-1])
	var panel: ColorRect = game._overlay()
	var box: VBoxContainer = game._overlay_box(panel, 660, 324)
	box.add_child(game._label("Kết quả kiểm chứng", 34))
	box.add_child(game._label("Test Contract: %d/%d ca đạt, gồm hồi quy" % [test.passed, test.tests], 20))
	box.add_child(game._label("Headless: %s · %d điểm ở scenario bình minh" % [outcome.state, outcome.score], 20))
	box.add_child(game._label("Benchmark: %.1f FPS · 1%% low %.1f FPS" % [benchmark.avg_fps, benchmark.p1_low_fps], 20))
	box.add_child(game._label("Soak: %d Đêm · %d crash · %.1f → %.1f MiB RSS" % [
		soak.nights, soak.crashes, soak.mem_start_mb, soak.mem_end_mb], 20))
	await hold_frames(192)
	quit(0)

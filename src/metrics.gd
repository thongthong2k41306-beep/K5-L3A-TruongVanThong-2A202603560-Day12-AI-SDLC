extends SceneTree
const Simulation = preload("res://src/simulation.gd")
const Layout = preload("res://src/night_layout.gd")
var directory: String
var game: Node3D
var origin_usec := 0
var previous_usec := 0
var first_measurement_usec := 0
var seconds := 0.0
var load_ms := 0.0
var samples: Array[float] = []

func _initialize() -> void:
	call_deferred("run")

func write_json(name: String, value: Dictionary) -> void:
	var file := FileAccess.open(directory.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	directory = args[1]
	var seed_value := int(args[2])
	write_json("pid.json", {"pid": OS.get_process_id()})
	if args[0] == "bench":
		run_benchmark(seed_value, float(args[3]), float(args[4]))
	else:
		await run_soak(seed_value, int(args[3]))

func run_benchmark(seed_value: int, duration: float, process_start: float) -> void:
	seconds = duration
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var shades: Array = []
	var motes: Array = []
	for i in 200:
		var position := Layout.radial(37.0 * sqrt((i + 0.5) / 200.0), i * 137.507764 + rng.randf_range(-2, 2))
		shades.append({"pos": [position.x, 0, position.z], "state": "wander"})
	for i in 100:
		var position := Layout.radial(37.0 * sqrt(rng.randf()), rng.randf_range(0, 360))
		motes.append([position.x, 0, position.z])
	game = load("res://scenes/main.tscn").instantiate()
	game.benchmark_mode = true
	game.sim = Simulation.new(seed_value, {"random_motes": false, "random_shades": false,
		"motes": motes, "shades": shades,
		"lanterns": [{"id": "L1", "lit": true}, {"id": "L2", "lit": true}, {"id": "L3", "lit": true}]})
	root.add_child(game)
	game.menu.hide()
	game.camera.position = Vector3(30, 15, 0)
	game.camera.look_at(Vector3.ZERO)
	await RenderingServer.frame_post_draw
	load_ms = (Time.get_unix_time_from_system() - process_start) * 1000
	origin_usec = Time.get_ticks_usec()
	RenderingServer.frame_post_draw.connect(record_frame)

func record_frame() -> void:
	var now := Time.get_ticks_usec()
	var elapsed := (now - origin_usec) / 1000000.0
	var angle := elapsed * TAU / 15.0
	game.camera.position = Vector3(cos(angle) * 30, 15, -sin(angle) * 30)
	game.camera.look_at(Vector3.ZERO)
	if elapsed < 3:
		return
	if first_measurement_usec == 0:
		first_measurement_usec = now
		previous_usec = now
		write_json("measuring.json", {})
		return
	var deadline := first_measurement_usec + int(seconds * 1000000.0)
	if now <= deadline:
		samples.append((now - previous_usec) / 1000.0)
		previous_usec = now
	if now >= deadline:
		RenderingServer.frame_post_draw.disconnect(record_frame)
		samples.sort()
		var count := samples.size()
		if count == 0:
			printerr("Benchmark did not record any complete frames")
			quit(1)
			return
		var total := 0.0
		var slow_total := 0.0
		var slow_count := maxi(1, ceili(count * 0.01))
		for sample in samples:
			total += sample
		for i in range(count - slow_count, count):
			slow_total += samples[i]
		write_json("result.json", {"contract_version": "1.3", "avg_fps": count * 1000.0 / total,
			"p1_low_fps": 1000.0 * slow_count / slow_total,
			"frame_ms_p95": samples[ceili(count * 0.95) - 1], "frames": count, "load_ms": load_ms,
			"vsync_off": DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED,
			"renderer": "Godot %s / Compatibility OpenGL / %s" % [Engine.get_version_info().string, RenderingServer.get_video_adapter_name()],
			"os": OS.get_name()})
		quit(0)

func sample_memory(name: String) -> void:
	write_json(name + ".json", {})
	var deadline := Time.get_ticks_msec() + 10000
	while not FileAccess.file_exists(directory.path_join(name + ".ack")) and Time.get_ticks_msec() < deadline:
		await create_timer(0.02).timeout

func run_soak(seed_value: int, nights: int) -> void:
	var start := Time.get_ticks_usec()
	var results: Array[String] = []
	for i in nights:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + i
		var sim = Simulation.new(seed_value + i, {}, i % 3 + 1)
		if i == 0:
			await sample_memory("start")
		var move := [0.0, 0.0]
		var max_ticks := roundi(sim.initial_time * 60)
		for tick in max_ticks:
			if tick % 30 == 0:
				var angle := rng.randf() * TAU
				move = [cos(angle), sin(angle)]
			sim.step({"move": move, "jump": rng.randf() < 0.05, "dash": rng.randf() < 0.03,
				"pulse": rng.randf() < 0.02, "interact": rng.randf() < 0.10})
			if sim.state != "playing":
				break
		results.append(sim.state)
		sim = null
	await sample_memory("end")
	write_json("result.json", {"nights": nights, "crashes": 0, "results": results,
		"duration_s": (Time.get_ticks_usec() - start) / 1000000.0})
	quit(0)

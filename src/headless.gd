extends SceneTree
const Simulation = preload("res://src/simulation.gd")
const Validation = preload("res://src/validation.gd")

func _initialize() -> void:
	call_deferred("run")

func fail(message: String, code: int = 2) -> void:
	printerr(message)
	quit(code)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var options: Dictionary = {"--seed": "1", "--night": "1", "--snapshot-every": "10"}
	var known := ["--seed", "--night", "--scenario", "--inputs", "--ticks", "--out", "--snapshot-every"]
	if args.size() % 2 != 0:
		fail("Expected --option value pairs")
		return
	for i in range(0, args.size(), 2):
		if not known.has(args[i]):
			fail("Unknown option: " + args[i])
			return
		options[args[i]] = args[i + 1]
	for key in ["--seed", "--night", "--ticks", "--snapshot-every"]:
		if not options.has(key) or not str(options[key]).is_valid_int():
			fail("Missing or invalid integer: " + key)
			return
	var night := int(options["--night"])
	if night < 1 or night > 3 or int(options["--ticks"]) < 0 or int(options["--snapshot-every"]) <= 0 or not options.has("--out"):
		fail("Use --night 1..3, --ticks >= 0, --snapshot-every > 0 and --out path")
		return
	var fixtures: Dictionary = {}
	for kind in ["scenario", "inputs"]:
		if options.has("--" + kind):
			var path: String = options["--" + kind]
			if not FileAccess.file_exists(path):
				fail("Cannot read " + path)
				return
			var parser := JSON.new()
			if parser.parse(FileAccess.get_file_as_string(path)) != OK:
				fail("Invalid JSON in " + path + ": " + parser.get_error_message())
				return
			fixtures[kind] = parser.data
	var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game.contract.json")).tuning
	var error := Validation.scenario(fixtures.get("scenario", {}), tuning, night)
	if error.is_empty():
		error = Validation.inputs(fixtures.get("inputs", {"frames": []}))
	if not error.is_empty():
		fail(error)
		return
	var output := FileAccess.open(options["--out"], FileAccess.WRITE)
	if output == null:
		fail("Cannot write output: " + str(options["--out"]), 1)
		return
	var sim = Simulation.new(int(options["--seed"]), fixtures.get("scenario", {}), night)
	output.store_line(JSON.stringify(sim.snapshot()))
	output.store_line(JSON.stringify({"type": "event", "tick": 0, "name": "night_start", "data": {"night": night}}))
	var frames: Array = fixtures.get("inputs", {"frames": []}).frames
	var frame_index := 0
	var input: Dictionary = {}
	for k in range(int(options["--ticks"])):
		if frame_index < frames.size() and int(frames[frame_index].tick) == k:
			input.merge(frames[frame_index], true)
			frame_index += 1
		sim.step(input)
		for event in sim.events:
			output.store_line(JSON.stringify(event))
		if sim.tick % int(options["--snapshot-every"]) == 0:
			output.store_line(JSON.stringify(sim.snapshot()))
		if sim.state == "won" or sim.state == "lost":
			break
	output.store_line(JSON.stringify({"type": "end", "ticks": sim.tick, "state": sim.state, "score": sim.score}))
	output.close()
	quit(0)

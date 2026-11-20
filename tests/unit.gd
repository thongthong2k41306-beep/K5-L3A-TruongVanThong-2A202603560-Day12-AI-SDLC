extends SceneTree
const Simulation = preload("res://src/simulation.gd")
const Leaderboard = preload("res://src/leaderboard.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(Simulation.horizontal(Vector3(0, 100, 0), Vector3(3, -20, 4)) == 5, "XZ distance ignores Y")
	check(Simulation.rounded_pos(Vector3(1.23456, 0, -2.34567)) == [1.235, 0.0, -2.346], "round to three decimals")
	var sim = Simulation.new(7, {"random_motes": false, "random_shades": false,
		"player": {"carried": 20, "successful_lights": 5}, "lanterns": [{"id": "L1", "pos": [2, 0, 0]}, {"id": "L2", "pos": [-2, 0, 0]}]})
	check(sim.nearest_lantern().id == "L1", "nearest tie resolves in L1..L5 order")
	sim.step({"interact": true})
	check(sim.lanterns[0].lit and sim.player.carried == 10, "deposits only needed amount")
	check(sim.nearest_lantern().id == "L2", "full lamp is not a candidate")
	sim.step({"interact": true})
	check(not sim.lanterns[1].lit, "holding interact does not trigger again")
	sim.player.pos.x = -2
	sim.step({"interact": false})
	sim.step({"interact": true})
	check(sim.lanterns[1].lit, "release and press triggers another deposit")
	sim = Simulation.new(1, {"random_motes": false, "random_shades": false,
		"lanterns": [{"id": "L1", "pos": [0, 0, 0], "lit": true}]})
	var crossing: Vector3 = sim._safe_move(Vector3(-10, 0, 0), Vector3(10, 0, 0))
	check(crossing.is_equal_approx(Vector3(-5, 0, 0)), "safe circle catches a segment crossing entirely through it")
	var away: Vector3 = sim._safe_move(Vector3(5, 0, 0), Vector3(6, 0, 0))
	check(away.is_equal_approx(Vector3(6, 0, 0)), "shade can move away from safety boundary")
	check(sim._outside_safe(Vector3.ZERO).is_equal_approx(Vector3(5, 0, 0)), "inside-safe correction has deterministic fallback")
	sim = Simulation.new(1, {"random_motes": false, "random_shades": false, "time_left_s": 0})
	sim.step({})
	var tick: int = sim.tick
	sim.step({"move": [1, 0]})
	check(sim.tick == tick and sim.player.pos == Vector3.ZERO, "terminal state cannot keep simulating")
	var ranking_path := "res://.tools/unit-ranking.json"
	if FileAccess.file_exists(ranking_path):
		DirAccess.remove_absolute(ranking_path)
	var board := Leaderboard.new(ranking_path)
	check(board.record("no!", 0, 0, 42) == ERR_INVALID_PARAMETER, "bad leaderboard name")
	check(board.record("MayFirst", 50, 2, 42) == OK, "initial score persists")
	check(board.record("MayLater", 50, 2, 43) == OK, "tied score persists")
	for i in 14:
		board.record("Seed_%d" % i, i, 0, i)
	var ranking := Leaderboard.new(ranking_path).entries()
	check(ranking.size() == 10 and ranking[2].score == 13 and ranking[-1].score == 6, "leaderboard limits to ten highest scores")
	check(ranking[0].name == "MayFirst" and ranking[1].name == "MayLater", "tied points preserve achievement order")
	DirAccess.remove_absolute(ranking_path)
	var report := {"unit_checks": checks, "failures": failures}
	var output := FileAccess.open("res://docs/proof/phase-4/unit-report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	quit(1 if failures else 0)

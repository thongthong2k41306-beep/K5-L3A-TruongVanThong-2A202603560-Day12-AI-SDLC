extends SceneTree
## A test controller only. It uses normal movement, interact and pulse inputs,
## with the real default world and all enemies enabled. No model state is edited.
const Simulation = preload("res://src/simulation.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sim = Simulation.new(2026)
	var frames: Array = []
	var next_interact := false
	var next_pulse := false
	var ticks := 0
	while sim.state == "playing" and ticks < 18000:
		var target: Vector3 = sim.player.pos
		var best := INF
		if sim.player.carried >= 10:
			for lantern in sim.lanterns:
				var distance: float = Simulation.horizontal(sim.player.pos, lantern.pos)
				if not lantern.lit and distance < best:
					best = distance
					target = lantern.pos
		else:
			for mote in sim.motes:
				var distance: float = Simulation.horizontal(sim.player.pos, mote.pos)
				# Prefer light away from active enemies, so the bot does not run into ink.
				for shade in sim.shades:
					if shade.state != "stunned" and Simulation.horizontal(mote.pos, shade.pos) < 5:
						distance += 18
				if distance < best:
					best = distance
					target = mote.pos
		var offset: Vector3 = target - sim.player.pos
		offset.y = 0
		var move := Vector2(offset.x, offset.z).limit_length(1)
		var interact: bool = not next_interact and not sim.nearest_lantern().is_empty() and sim.player.carried > 0
		var pulse := false
		for shade in sim.shades:
			if shade.state != "stunned" and Simulation.horizontal(sim.player.pos, shade.pos) < 4 and sim.player.carried >= 3 and sim.tick + 1 >= sim.pulse_ready_tick:
				pulse = not next_pulse
		var frame := {"tick": ticks, "move": [move.x, move.y], "cam_yaw_deg": 0, "interact": interact, "pulse": pulse}
		frames.append(frame)
		sim.step(frame)
		next_interact = interact
		next_pulse = pulse
		ticks += 1
	var directory := "res://docs/proof/phase-4/"
	var output := FileAccess.open(directory + "autoplay-inputs.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"frames": frames}))
	output.close()
	output = FileAccess.open(directory + "autoplay-report.json", FileAccess.WRITE)
	var report := {"seed": 2026, "ticks": sim.tick, "state": sim.state, "score": sim.score,
		"flames": sim.player.flames, "time_left_s": sim.time_left_s, "lanterns": sim.snapshot().lanterns}
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	quit(0 if sim.state in ["won", "lost"] else 1)

extends RefCounted
## The ONLY gameplay implementation: used by both the 3D scene and CLI.
const DT := 1.0 / 60.0
const EPS := 0.000001
const Layout = preload("res://src/night_layout.gd")
var tuning: Dictionary
var rng := RandomNumberGenerator.new()
var tick := 0
var sim_tick := 0
var night := 1
var exploration := false
var island_radius := 40.0
var grounded := true
var velocity := Vector3.ZERO
var facing := Vector3.BACK
var launch_velocity := Vector3.ZERO
var dash_direction := Vector3.ZERO
var dash_until := 0
var dash_ready_tick := 0
var charm_until := 0
var drifters: Array = []
var charms: Array = []
var random_drifters := true
var next_drifter_id := 1
var wind_enabled := true
var wind_active := false
var wind_dir := 0.0
var spawn_motes: Array[Vector3]
var spawn_shades: Array[Vector3]
var state := "playing"
var score := 0
var successful_lights := 0
var time_left_s := 300.0
var initial_time := 300.0
var player := {"pos": Vector3.ZERO, "carried": 0, "flames": 3}
var lanterns: Array = []
var motes: Array = []
var shades: Array = []
var events: Array = []
var random_motes := true
var random_shades := true
var next_mote_id := 1
var next_shade_id := 1
var vertical_speed := 0.0
var invuln_until := 0
var pulse_ready_tick := 0
var buttons := {"jump": false, "interact": false, "pulse": false, "pause": false, "dash": false}

func _init(seed_value: int = 1, scenario: Dictionary = {}, night_number: int = 1, explore: bool = false) -> void:
	night = night_number
	exploration = explore and night == 1
	island_radius = 60.0 if exploration else Layout.RADII[night - 1]
	spawn_motes = Layout.mote_points(night)
	spawn_shades = Layout.shade_points(night)
	tuning = JSON.parse_string(FileAccess.get_file_as_string("res://game.contract.json"))["tuning"]
	rng.seed = seed_value
	if exploration:
		spawn_motes.append_array(Layout.ring(20, 48))
		spawn_shades = Layout.ring(16, 56, 12)
	player.flames = int(tuning.flames)
	initial_time = float(scenario.get("time_left_s", tuning["night%d_duration_s" % night]))
	time_left_s = initial_time
	random_motes = scenario.get("random_motes", true)
	random_shades = scenario.get("random_shades", true)
	random_drifters = scenario.get("random_drifters", true)
	wind_enabled = scenario.get("wind_enabled", true)
	var lamp_positions: Array = Layout.LANTERNS[night - 1]
	if exploration:
		lamp_positions = []
		var offset := rng.randf_range(0, 360)
		for i in 5:
			lamp_positions.append(Layout.radial(rng.randf_range(17, 47), offset + i * 72 + rng.randf_range(-17, 17)))
		for i in range(lamp_positions.size() - 1, 0, -1):
			var other := rng.randi_range(0, i)
			var previous: Vector3 = lamp_positions[i]
			lamp_positions[i] = lamp_positions[other]
			lamp_positions[other] = previous
	for pos in lamp_positions:
		lanterns.append({"id": "L%d" % (lanterns.size() + 1), "pos": pos, "lit": false, "deposited": 0,
			"fuel_units": 0, "ever_lit": false, "relit_count": 0})
	for change in scenario.get("lanterns", []):
		for lantern in lanterns:
			if lantern.id == change.id:
				if change.has("pos"):
					lantern.pos = vec(change.pos)
				lantern.deposited = int(change.get("deposited", 0))
				lantern.ever_lit = change.get("ever_lit", false)
				lantern.lit = change.get("lit", lantern.deposited >= light_cost(lantern))
				if lantern.lit:
					lantern.deposited = light_cost(lantern)
					lantern.ever_lit = true
					lantern.fuel_units = roundi(float(change.get("fuel", tuning.fuel_max)) * 60)
	var p: Dictionary = scenario.get("player", {})
	player.pos = vec(p.get("pos", [0, 0, 0]))
	player.carried = int(p.get("carried", 0))
	player.flames = int(p.get("flames", tuning.flames))
	successful_lights = int(p.get("successful_lights", 0))
	invuln_until = int(p.get("invuln_ticks", 0))
	dash_ready_tick = int(p.get("dash_cd_ticks", 0))
	pulse_ready_tick = int(p.get("pulse_cd_ticks", 0))
	charm_until = int(p.get("charm_ticks", 0))
	grounded = _has_floor(player.pos)
	if scenario.has("motes"):
		for pos in scenario.motes:
			_add_mote(vec(pos))
	elif random_motes:
		for pos in spawn_motes:
			_add_mote(pos)
	if scenario.has("shades"):
		# Reserve supplied IDs before assigning any automatic IDs.
		var reserved: Array = []
		for shade in scenario.shades:
			if shade.has("id"):
				reserved.append(shade.id)
		for shade in scenario.shades:
			var id: String = shade.get("id", "")
			if id.is_empty():
				id = _shade_id(reserved)
			_add_shade(vec(shade.pos), id)
			shades.back().state = shade.get("state", "chase")
			shades.back().stunned_until = int(shade.get("state_ticks_left", 0))
			shades.back().target_lantern_id = shade.get("target_lantern_id", "")
	for drifter in scenario.get("drifters", []):
		_add_drifter(vec(drifter.pos), drifter)
	var default_charms: Array = []
	for pos in Layout.charm_points(night):
		default_charms.append({"pos": [pos.x, pos.y, pos.z]})
	for charm in scenario.get("charms", default_charms):
		charms.append({"id": charm.get("id", "C%d" % (charms.size() + 1)), "pos": vec(charm.pos),
			"ready": int(charm.get("respawn_ticks", 0 if charm.get("available", true) else 2700))})

static func vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

static func horizontal(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func rounded_pos(p: Vector3) -> Array:
	return [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)]

func _add_mote(pos: Vector3, dropped: bool = false) -> void:
	motes.append({"id": "M%d" % next_mote_id, "pos": pos, "kind": "dropped" if dropped else "random",
		"expires": sim_tick + 600 if dropped else 0})
	next_mote_id += 1

func _shade_id(reserved: Array = []) -> String:
	while true:
		var id := "S%d" % next_shade_id
		next_shade_id += 1
		var used := reserved.has(id)
		for shade in shades:
			used = used or shade.id == id
		if not used:
			return id
	return ""

func _add_shade(pos: Vector3, id: String) -> void:
	shades.append({"id": id, "pos": pos, "state": "chase", "stunned_until": 0,
		"target_lantern_id": "", "drain_ticks": 0, "repel_until": 0, "repel_goal": pos})

func emit_event(name: String, data: Dictionary) -> void:
	events.append({"type": "event", "tick": tick, "name": name, "data": data})

func step(input: Dictionary) -> void:
	events = []
	if state == "won" or state == "lost":
		return
	tick += 1
	if _pressed(input, "pause"):
		state = "playing" if state == "paused" else "paused"
		emit_event("resumed" if state == "playing" else "paused", {})
	if state == "paused":
		_remember_buttons(input)
		return
	sim_tick += 1
	time_left_s = maxf(0, initial_time - sim_tick * DT)
	_update_fuel()
	_update_wind()
	motes = motes.filter(func(mote: Dictionary) -> bool: return mote.expires == 0 or mote.expires > sim_tick)
	var move: Array = input.get("move", [0, 0])
	var direction := Vector2(float(move[0]), float(move[1])).limit_length(1.0)
	var angle := deg_to_rad(float(input.get("cam_yaw_deg", 0)))
	var world_dir := Vector3(direction.x * cos(angle) + direction.y * sin(angle), 0, -direction.x * sin(angle) + direction.y * cos(angle))
	_move_player(world_dir, input)
	_pickup()
	_pickup_charms()
	if _pressed(input, "interact"):
		_deposit()
	if _pressed(input, "pulse"):
		_pulse()
	_move_drifters()
	_update_shades()
	_spawn()
	_remember_buttons(input)
	if player.flames <= 0:
		_finish("lost", "no_flames")
	elif time_left_s <= 0:
		var lit := lanterns.filter(func(lantern: Dictionary) -> bool: return lantern.lit)
		if lit.size() >= required_lights():
			for lantern in lit:
				score += int(tuning.score.per_dawn_lantern) + floori(lantern.fuel_units / 60.0)
			score += int(player.flames) * int(tuning.score.per_flame_left)
			_finish("won", "dawn_survived")
		else:
			_finish("lost", "dawn")

func capacity() -> int:
	return mini(int(tuning.capacity_max), int(tuning.carry_capacity) + 2 * mini(successful_lights, int(tuning.capacity_max)))

func required_lights() -> int:
	return ceili(lanterns.size() * float(tuning.win_ratio))

func light_cost(lantern: Dictionary) -> int:
	return int(tuning.relight_cost if lantern.ever_lit else tuning.lantern_cost)

func fuel(lantern: Dictionary) -> float:
	return snappedf(lantern.fuel_units / 60.0, 0.1)

func has_safety(lantern: Dictionary) -> bool:
	return lantern.lit and lantern.fuel_units >= int(tuning.low_fuel_threshold) * 60

func _can_drain(shade: Dictionary, lantern: Dictionary) -> bool:
	return not lantern.is_empty() and lantern.lit and lantern.fuel_units > 0 and not has_safety(lantern) and horizontal(shade.pos, lantern.pos) <= 2.0 + EPS

func _lantern_by_id(id: String) -> Dictionary:
	for lantern in lanterns:
		if lantern.id == id:
			return lantern
	return {}

func _update_fuel() -> void:
	# Units are sixtieths of one fuel point. Apply all pulls before reporting their shared result.
	var draining: Dictionary = {}
	for shade in shades:
		if shade.state != "drain":
			continue
		var target := _lantern_by_id(shade.target_lantern_id)
		if target.is_empty() or not _can_drain(shade, target):
			_stop_draining(shade, "wander")
			continue
		shade.drain_ticks += 1
		if not draining.has(target.id):
			draining[target.id] = []
		draining[target.id].append(shade)
	for lantern in lanterns:
		if not lantern.lit:
			continue
		var attackers: Array = draining.get(lantern.id, [])
		lantern.fuel_units = maxi(0, lantern.fuel_units - int(tuning.fuel_decay_per_s) - int(tuning.drain_per_s) * attackers.size())
		for shade in attackers:
			if shade.drain_ticks % 60 == 0:
				emit_event("fuel_drain", {"lantern_id": lantern.id, "shade_id": shade.id, "fuel": fuel(lantern)})
		if lantern.fuel_units == 0:
			lantern.lit = false
			lantern.deposited = 0
			emit_event("lantern_out", {"lantern_id": lantern.id})
			for shade in attackers:
				_stop_draining(shade, "wander")

func _stop_draining(shade: Dictionary, next_state: String) -> void:
	shade.state = next_state
	shade.target_lantern_id = ""
	shade.drain_ticks = 0

func _remember_buttons(input: Dictionary) -> void:
	for key in buttons:
		buttons[key] = input.get(key, false)

func _pressed(input: Dictionary, key: String) -> bool:
	return bool(input.get(key, false)) and not bool(buttons[key])

func _has_floor(pos: Vector3) -> bool:
	for height in _floors_at(pos):
		if absf(pos.y - height) < 0.002:
			return true
	return false

func _floors_at(pos: Vector3) -> Array[float]:
	if not exploration:
		return Layout.floor_surfaces(night, pos)
	var surfaces: Array[float] = []
	if horizontal(pos, Vector3.ZERO) <= island_radius:
		surfaces.append(0.0)
	return surfaces

func _move_player(direction: Vector3, input: Dictionary) -> void:
	if direction.length_squared() > EPS:
		facing = direction.normalized()
	if grounded and _pressed(input, "jump"):
		vertical_speed = 7
		grounded = false
	if grounded:
		for pad in Layout.pads(night):
			if absf(player.pos.y - pad.pos.y) < 0.002 and horizontal(player.pos, pad.pos) <= 1:
				launch_velocity = Vector3(pad.vel.x, 0, pad.vel.z)
				vertical_speed = pad.vel.y
				grounded = false
				break
	var charmed := sim_tick < charm_until
	if _pressed(input, "dash") and sim_tick >= dash_until and (charmed or sim_tick >= dash_ready_tick):
		dash_direction = facing
		dash_until = sim_tick + int(round(float(tuning.dash_duration_s) * 60))
		if not charmed:
			dash_ready_tick = sim_tick + int(round(float(tuning.dash_cooldown_s) * 60))
		emit_event("dash", {})
	var horizontal_velocity := direction * (7.2 if charmed else float(tuning.player_speed))
	if launch_velocity != Vector3.ZERO:
		horizontal_velocity = launch_velocity
	if sim_tick < dash_until:
		horizontal_velocity = dash_direction * float(tuning.dash_speed)
	if wind_active:
		horizontal_velocity += Layout.radial(2.0, wind_dir)
	var previous: Vector3 = player.pos
	var next := previous + horizontal_velocity * DT
	if night == 3 and previous.y >= 6 and horizontal(next, Vector3.ZERO) < Layout.TOWER_RADIUS:
		next.x = previous.x
		next.z = previous.z
	if not grounded:
		next.y += vertical_speed * DT
		vertical_speed -= 20.0 * DT
	var landing := -INF
	for height in _floors_at(next):
		var step_up := 0.22 if grounded and night == 3 else 0.002
		if height <= previous.y + step_up and next.y <= height + 0.002 and vertical_speed <= 0:
			if grounded and previous.y - height > 0.22:
				continue
			landing = maxf(landing, height)
	if is_finite(landing):
		next.y = landing
		vertical_speed = 0
		launch_velocity = Vector3.ZERO
		grounded = true
	else:
		grounded = false
	player.pos = next
	velocity = (next - previous) / DT
	if player.pos.y < -5.0:
		var lost := int(player.carried)
		player.carried = 0
		player.flames -= 1
		player.pos = Vector3.ZERO
		velocity = Vector3.ZERO
		vertical_speed = 0
		grounded = true
		launch_velocity = Vector3.ZERO
		dash_until = sim_tick
		invuln_until = sim_tick + int(round(float(tuning.invuln_s) * 60))
		emit_event("player_hit", {"by": "fall", "flames": player.flames, "dropped": 0, "lost": lost})

func _pickup_charms() -> void:
	for charm in charms:
		if charm.ready <= sim_tick and horizontal(player.pos, charm.pos) <= float(tuning.pickup_radius) + EPS:
			charm_until = sim_tick + 600
			charm.ready = sim_tick + 2700
			emit_event("charm_picked", {"charm_id": charm.id, "charm_ticks": 600})

func _add_drifter(pos: Vector3, fixture: Dictionary = {}) -> void:
	var id: String = fixture.get("id", "")
	if id.is_empty():
		while id.is_empty():
			var candidate := "D%d" % next_drifter_id
			next_drifter_id += 1
			if not drifters.any(func(d: Dictionary) -> bool: return d.id == candidate):
				id = candidate
	drifters.append({"id": id, "pos": pos, "state": fixture.get("state", "idle"),
		"stolen": int(fixture.get("stolen", 0)), "until": sim_tick + int(fixture.get("state_ticks_left", 240)),
		"direction": Vector3.RIGHT, "phase": float(drifters.size())})

func _flee(drifter: Dictionary, duration: int) -> void:
	drifter.state = "flee"
	drifter.until = sim_tick + duration
	var away: Vector3 = drifter.pos - player.pos
	away.y = 0
	drifter.direction = away.normalized() if away.length_squared() > EPS else Vector3.RIGHT

func _move_drifters() -> void:
	drifters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id).naturalnocasecmp_to(str(b.id)) < 0)
	for drifter in drifters:
		if drifter.state == "flee":
			if sim_tick >= drifter.until:
				drifter.state = "removed"
			else:
				drifter.pos += drifter.direction * 7 * DT
			continue
		if drifter.state == "removed":
			continue
		var offset: Vector3 = player.pos - drifter.pos
		offset.y = 0
		if player.carried >= 5 and offset.length() <= 15:
			drifter.state = "chase"
			drifter.pos += offset.limit_length(7 * DT)
		else:
			drifter.state = "idle"
			drifter.pos += Layout.radial(2 * DT, sim_tick * 1.5 + drifter.phase * 90)
	for drifter in drifters:
		if drifter.state == "chase" and horizontal(player.pos, drifter.pos) <= 1.2:
			var amount := mini(3, int(player.carried))
			player.carried -= amount
			drifter.stolen = amount
			_flee(drifter, 240)
			emit_event("drifter_steal", {"drifter_id": drifter.id, "amount": amount, "carried": player.carried})
	drifters = drifters.filter(func(d: Dictionary) -> bool: return d.state != "removed")

func _update_wind() -> void:
	wind_active = false
	if night != 3 or not wind_enabled:
		return
	if sim_tick >= 1800 and sim_tick % 1800 == 0:
		wind_dir = rng.randf_range(0, 360)
	wind_active = sim_tick >= 1800 and sim_tick % 1800 < 300

func _spawn() -> void:
	if random_motes and sim_tick % 120 == 0:
		var choices := spawn_motes.filter(func(pos: Vector3) -> bool:
			return not motes.any(func(mote: Dictionary) -> bool: return mote.kind == "random" and mote.pos == pos))
		if not choices.is_empty():
			_add_mote(choices[rng.randi_range(0, choices.size() - 1)])
	var interval: int = [480, 420, 360][night - 1]
	var max_shades: int = [6, 8, 10][night - 1]
	var first := 300 if night == 1 else interval
	if random_shades and sim_tick >= first and (sim_tick - first) % interval == 0:
		var candidates := spawn_shades.filter(func(pos: Vector3) -> bool: return horizontal(player.pos, pos) >= 15)
		for i in (2 if night == 1 and sim_tick == first else 1):
			if candidates.is_empty() or shades.size() >= max_shades:
				break
			var id := _shade_id()
			var index := rng.randi_range(0, candidates.size() - 1)
			_add_shade(candidates.pop_at(index), id)
			shades.back().state = "spawning"
			shades.back().stunned_until = sim_tick + 30
			emit_event("shade_spawned", {"id": id})
	if night > 1 and random_drifters and sim_tick % 1200 == 0 and drifters.size() < 2:
		_add_drifter(spawn_shades[rng.randi_range(0, spawn_shades.size() - 1)])

func _pickup() -> void:
	var remaining: Array = []
	for mote in motes:
		if player.carried < capacity() and horizontal(player.pos, mote.pos) <= float(tuning.pickup_radius) + EPS:
			player.carried += 1
			emit_event("mote_picked", {"carried": player.carried})
		else:
			remaining.append(mote)
	motes = remaining

func nearest_lantern() -> Dictionary:
	var nearest: Dictionary = {}
	var best := float(tuning.interact_radius) + EPS
	for lantern in lanterns:
		var distance := horizontal(player.pos, lantern.pos)
		if (not lantern.lit or lantern.fuel_units < int(tuning.fuel_max) * 60) and distance <= best:
			if nearest.is_empty() or distance < best - EPS:
				nearest = lantern
				best = distance
	return nearest

func _deposit() -> void:
	var lantern := nearest_lantern()
	if lantern.is_empty() or player.carried <= 0:
		return
	if lantern.lit:
		var max_units := int(tuning.fuel_max) * 60
		var per_mote := int(tuning.fuel_per_mote) * 60
		var used := mini(int(player.carried), ceili((max_units - lantern.fuel_units) / float(per_mote)))
		var was_safe := has_safety(lantern)
		lantern.fuel_units = mini(max_units, lantern.fuel_units + used * per_mote)
		player.carried -= used
		score += used * int(tuning.score.per_mote)
		emit_event("refuel", {"lantern_id": lantern.id, "amount": used, "fuel": fuel(lantern)})
		if not was_safe and has_safety(lantern):
			_repel_shades(lantern)
		return
	var cost := light_cost(lantern)
	var amount := mini(int(player.carried), cost - int(lantern.deposited))
	if amount <= 0:
		return
	player.carried -= amount
	lantern.deposited += amount
	score += amount * int(tuning.score.per_mote)
	emit_event("deposit", {"lantern_id": lantern.id, "amount": amount, "deposited": lantern.deposited})
	if lantern.deposited >= cost:
		var relight: bool = lantern.ever_lit
		lantern.lit = true
		lantern.ever_lit = true
		lantern.fuel_units = int(tuning.fuel_max) * 60
		lantern.relit_count += int(relight)
		successful_lights += 1
		score += int(tuning.score.per_relight if relight else tuning.score.per_lantern)
		emit_event("lantern_lit", {"lantern_id": lantern.id, "relight": relight})
		_repel_shades(lantern)

func _repel_shades(lantern: Dictionary) -> void:
	for shade in shades:
		var offset: Vector3 = shade.pos - lantern.pos
		offset.y = 0
		if offset.length() > 6.0 + EPS:
			continue
		var outward := offset.normalized() if offset.length_squared() > EPS else Vector3.RIGHT
		shade.repel_goal = Vector3(lantern.pos.x, shade.pos.y, lantern.pos.z) + outward * 6.0
		shade.repel_until = sim_tick + 30
		if shade.state == "drain":
			_stop_draining(shade, "wander")

func _pulse() -> void:
	if player.carried < int(tuning.pulse_cost) or sim_tick < pulse_ready_tick:
		return
	player.carried -= int(tuning.pulse_cost)
	pulse_ready_tick = sim_tick + int(round(float(tuning.pulse_cooldown_s) * 60))
	var ids: Array = []
	for shade in shades:
		if horizontal(player.pos, shade.pos) <= float(tuning.pulse_radius) + EPS:
			var was_draining: bool = shade.state == "drain"
			_stop_draining(shade, "stunned")
			shade.stunned_until = sim_tick + int(round(float(tuning.pulse_stun_s) * 60))
			var away: Vector3 = shade.pos - player.pos
			away.y = 0
			if away.length_squared() < EPS:
				away = Vector3.RIGHT
			shade.pos += away.normalized() * float(tuning.pulse_push_m)
			ids.append(shade.id)
			score += int(tuning.score.per_drain_stun if was_draining else tuning.score.per_stun)
	for drifter in drifters:
		if horizontal(player.pos, drifter.pos) > float(tuning.pulse_radius) + EPS:
			continue
		if drifter.state == "chase":
			_flee(drifter, 240)
		elif drifter.state == "flee" and drifter.stolen > 0:
			for i in drifter.stolen:
				_add_mote(drifter.pos, true)
			emit_event("drifter_drop", {"drifter_id": drifter.id, "amount": drifter.stolen})
			drifter.stolen = 0
			_flee(drifter, 120)
	emit_event("pulse", {"stunned_ids": ids})

func _outside_safe(pos: Vector3) -> Vector3:
	var result := pos
	for lantern in lanterns:
		if not has_safety(lantern):
			continue
		var delta: Vector3 = result - lantern.pos
		delta.y = 0
		if delta.length() < float(tuning.safe_radius):
			if delta.length_squared() < EPS:
				delta = Vector3.RIGHT
			var offset := delta.normalized() * float(tuning.safe_radius)
			result.x = lantern.pos.x + offset.x
			result.z = lantern.pos.z + offset.z
	return result

func _safe_move(start: Vector3, target: Vector3) -> Vector3:
	# Intersect the complete movement segment with each safe circle.
	var delta := Vector2(target.x - start.x, target.z - start.z)
	var fraction := 1.0
	if delta.length_squared() <= EPS * EPS:
		return start
	for lantern in lanterns:
		if not has_safety(lantern):
			continue
		var offset := Vector2(start.x - lantern.pos.x, start.z - lantern.pos.z)
		var a := delta.length_squared()
		var b := 2.0 * offset.dot(delta)
		var c := offset.length_squared() - float(tuning.safe_radius) * float(tuning.safe_radius)
		var discriminant := b * b - 4.0 * a * c
		if discriminant >= 0:
			var entry := (-b - sqrt(discriminant)) / (2.0 * a)
			if entry >= -EPS and entry <= fraction:
				fraction = maxf(0, entry)
	return start + (target - start) * fraction

func benchmark_step() -> void:
	sim_tick += 1
	_update_shades(true)

func _update_shades(benchmark: bool = false) -> void:
	shades.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id).naturalnocasecmp_to(str(b.id)) < 0)
	for shade in shades:
		if sim_tick < int(shade.repel_until):
			shade.pos = shade.pos.lerp(shade.repel_goal, 1.0 / float(shade.repel_until - sim_tick))
			continue
		shade.pos = _outside_safe(shade.pos)
		if sim_tick < int(shade.stunned_until):
			continue
		var offset: Vector3 = player.pos - shade.pos
		offset.y = 0
		if shade.state == "drain":
			if offset.length() <= 6.0 + EPS:
				_stop_draining(shade, "chase")
			elif _can_drain(shade, _lantern_by_id(shade.target_lantern_id)):
				continue
			else:
				_stop_draining(shade, "wander")
		var just_recovered: bool = shade.state == "stunned"
		if shade.state == "spawning" or just_recovered:
			shade.state = "wander"
		if shade.state == "wander":
			var weak := _nearest_shade_lantern(shade.pos, true)
			if not weak.is_empty():
				var toward: Vector3 = weak.pos - shade.pos
				toward.y = 0
				shade.pos = _safe_move(shade.pos, shade.pos + toward.limit_length(float(tuning.shade_speed) * DT))
				if not just_recovered and _can_drain(shade, weak):
					shade.state = "drain"
					shade.target_lantern_id = weak.id
				continue
			if offset.length() <= 18 and not just_recovered and not benchmark:
				shade.state = "chase"
			else:
				var drift := Layout.radial(float(tuning.shade_speed) * 0.45 * DT, sim_tick + str(shade.id).hash() % 360)
				var dark := _nearest_shade_lantern(shade.pos, false)
				if not dark.is_empty():
					var toward: Vector3 = dark.pos - shade.pos
					toward.y = 0
					drift = toward.limit_length(float(tuning.shade_speed) * DT)
				shade.pos = _safe_move(shade.pos, shade.pos + drift)
				continue
		shade.state = "chase"
		var target: Vector3 = shade.pos + offset.limit_length(float(tuning.shade_speed) * DT)
		shade.pos = _safe_move(shade.pos, target)
		if horizontal(player.pos, shade.pos) <= float(tuning.shade_hit_radius) + EPS and sim_tick >= invuln_until:
			var dropped := int(floor(float(player.carried) * float(tuning.hit_drop_ratio)))
			player.carried -= dropped
			for i in dropped:
				var drop_pos: Vector3 = player.pos + Layout.radial(float(tuning.pickup_radius) + 0.3, 90.0 + i * 30.0)
				_add_mote(drop_pos, true)
			player.flames -= 1
			invuln_until = sim_tick + int(round(float(tuning.invuln_s) * 60))
			shade.state = "recoil"
			shade.stunned_until = sim_tick + 20
			emit_event("player_hit", {"by": "shade", "flames": player.flames, "dropped": dropped})
			if player.flames <= 0:
				break

func _nearest_shade_lantern(pos: Vector3, weak: bool) -> Dictionary:
	var nearest: Dictionary = {}
	var best := INF
	for lantern in lanterns:
		if (weak and lantern.lit and not has_safety(lantern)) or (not weak and not lantern.lit):
			var distance := horizontal(pos, lantern.pos)
			if distance < best - EPS:
				nearest = lantern
				best = distance
	return nearest

func _finish(result: String, reason: String) -> void:
	state = result
	emit_event("game_over", {"result": result, "reason": reason})

func snapshot() -> Dictionary:
	var ls: Array = []
	var ss: Array = []
	var ms: Array = []
	for lantern in lanterns:
		ls.append({"id": lantern.id, "pos": rounded_pos(lantern.pos), "lit": lantern.lit, "deposited": lantern.deposited,
			"fuel": fuel(lantern), "ever_lit": lantern.ever_lit, "relit_count": lantern.relit_count})
	for shade in shades:
		ss.append({"id": shade.id, "pos": rounded_pos(shade.pos), "state": shade.state})
	for mote in motes:
		ms.append({"id": mote.id, "pos": rounded_pos(mote.pos), "kind": mote.kind,
			"ttl_s": maxf(0, (mote.expires - sim_tick) * DT)})
	var ds: Array = []
	for drifter in drifters:
		ds.append({"id": drifter.id, "pos": rounded_pos(drifter.pos), "state": drifter.state, "stolen": drifter.stolen})
	var cs: Array = []
	for charm in charms:
		cs.append({"id": charm.id, "available": charm.ready <= sim_tick, "respawn_s": maxf(0, (charm.ready - sim_tick) * DT)})
	return {"type": "snapshot", "tick": tick, "sim_tick": sim_tick, "night": night, "state": state, "time_left_s": time_left_s, "score": score,
		"wind": {"active": wind_active, "dir_deg": wind_dir},
		"player": {"pos": rounded_pos(player.pos), "vel": rounded_pos(velocity), "flames": player.flames, "carried": player.carried,
			"grounded": grounded, "invuln": sim_tick < invuln_until, "capacity": capacity(),
			"dash_cd_s": maxf(0, (dash_ready_tick - sim_tick) * DT) if charm_until <= sim_tick else 0.0,
			"pulse_cd_s": maxf(0, (pulse_ready_tick - sim_tick) * DT),
			"charm_s": maxf(0, (charm_until - sim_tick) * DT)},
		"lanterns": ls, "shades": ss, "motes_active": motes.size(), "motes": ms, "drifters": ds, "charms": cs}

extends RefCounted
## Reject malformed fixtures before starting a simulation; never silently repair them.
static func number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))

static func integer(value: Variant) -> bool:
	return number(value) and float(value) == floor(float(value))

static func position(value: Variant) -> bool:
	return value is Array and value.size() == 3 and number(value[0]) and number(value[1]) and number(value[2])

static func inputs(value: Variant) -> String:
	if not value is Dictionary or not value.get("frames") is Array:
		return "inputs must contain a frames array"
	var previous := -1
	for frame in value.frames:
		if not frame is Dictionary or not integer(frame.get("tick")) or frame.tick < 0 or frame.tick <= previous:
			return "frame ticks must be nonnegative integers in strictly increasing order"
		previous = int(frame.tick)
		for key in frame:
			if not ["tick", "move", "cam_yaw_deg", "jump", "interact", "pulse", "dash", "pause"].has(key):
				return "unknown input field: " + str(key)
		if frame.has("move"):
			if not frame.move is Array or frame.move.size() != 2:
				return "move must have two components"
			for component in frame.move:
				if not number(component) or absf(float(component)) > 1:
					return "move components must be finite and between -1 and 1"
		if frame.has("cam_yaw_deg") and not number(frame.cam_yaw_deg):
			return "cam_yaw_deg must be finite"
		for key in ["jump", "interact", "pulse", "dash", "pause"]:
			if frame.has(key) and not frame[key] is bool:
				return key + " must be boolean"
	return ""

static func scenario(value: Variant, tuning: Dictionary, night: int = 1) -> String:
	if not value is Dictionary:
		return "scenario must be an object"
	for key in ["random_motes", "random_shades", "random_drifters", "wind_enabled"]:
		if value.has(key) and not value[key] is bool:
			return key + " must be boolean"
	if value.has("time_left_s") and (not number(value.time_left_s) or value.time_left_s < 0):
		return "time_left_s must be a nonnegative finite number"
	if value.has("player"):
		var p: Variant = value.player
		if not p is Dictionary:
			return "player must be an object"
		if p.has("pos") and not position(p.pos):
			return "player.pos must have three finite coordinates"
		for key in ["carried", "flames", "invuln_ticks", "dash_cd_ticks", "pulse_cd_ticks", "charm_ticks", "successful_lights"]:
			if p.has(key) and (not integer(p[key]) or p[key] < 0):
				return "player." + key + " must be a nonnegative integer"
		var capacity := mini(int(tuning.capacity_max), int(tuning.carry_capacity) + 2 * mini(int(p.get("successful_lights", 0)), int(tuning.capacity_max)))
		if p.get("carried", 0) > capacity:
			return "player.carried exceeds carry_capacity"
	if value.has("motes"):
		if not value.motes is Array:
			return "motes must be an array"
		for mote in value.motes:
			if not position(mote):
				return "mote position must have three finite coordinates"
	if value.has("shades"):
		if not value.shades is Array:
			return "shades must be an array"
		var ids: Array = []
		for shade in value.shades:
			if not shade is Dictionary or not position(shade.get("pos")):
				return "shade must contain a valid pos"
			if shade.has("id"):
				if not shade.id is String or shade.id.is_empty() or ids.has(shade.id):
					return "shade IDs must be nonempty unique strings"
				ids.append(shade.id)
			if shade.has("state") and not ["spawning", "wander", "chase", "recoil", "stunned", "drain"].has(shade.state):
				return "invalid shade state"
			if shade.has("target_lantern_id"):
				var target: Variant = shade.target_lantern_id
				if not target is String or (not target.is_empty() and not _lantern_ids(night).has(target)):
					return "invalid target_lantern_id"
			if shade.has("state_ticks_left") and (not integer(shade.state_ticks_left) or shade.state_ticks_left < 0):
				return "invalid state_ticks_left"
	for key in ["drifters", "charms"]:
		if not value.has(key):
			continue
		if not value[key] is Array:
			return key + " must be an array"
		var ids: Array = []
		for item in value[key]:
			if not item is Dictionary or not position(item.get("pos")):
				return key + " entry must have a valid pos"
			if item.has("id"):
				if not item.id is String or item.id.is_empty() or ids.has(item.id):
					return key + " IDs must be nonempty unique strings"
				ids.append(item.id)
			if key == "drifters" and not ["idle", "chase", "flee", "removed"].has(item.get("state", "idle")):
				return "invalid drifter state"
			if key == "charms" and not item.get("available", true) is bool:
				return "invalid charm availability"
			for field in ["stolen", "state_ticks_left", "respawn_ticks"]:
				if item.has(field) and (not integer(item[field]) or item[field] < 0):
					return "invalid " + field
	if value.has("lanterns"):
		if not value.lanterns is Array:
			return "lanterns must be an array"
		var ids: Array = []
		for lantern in value.lanterns:
			if not lantern is Dictionary or not _lantern_ids(night).has(lantern.get("id")) or ids.has(lantern.get("id")):
				return "lantern IDs must be unique and match the night"
			ids.append(lantern.id)
			if lantern.has("pos") and not position(lantern.pos):
				return "lantern.pos must have three finite coordinates"
			if lantern.has("lit") and not lantern.lit is bool:
				return "lantern.lit must be boolean"
			if lantern.has("ever_lit") and not lantern.ever_lit is bool:
				return "lantern.ever_lit must be boolean"
			if lantern.has("fuel") and (not number(lantern.fuel) or lantern.fuel < 0 or lantern.fuel > tuning.fuel_max):
				return "lantern.fuel must be between zero and fuel_max"
			if lantern.has("deposited") and (not integer(lantern.deposited) or lantern.deposited < 0 or lantern.deposited > tuning.lantern_cost):
				return "lantern.deposited must be an integer between zero and lantern_cost"
	return ""

static func _lantern_ids(night: int) -> Array:
	var ids: Array = []
	for i in range(4 + night):
		ids.append("L%d" % (i + 1))
	return ids

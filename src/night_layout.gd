extends RefCounted
## Ticket-02 map geometry shared by the renderer and simulation.
const NAMES := ["Đảo Bến", "Đảo Cầu Tre", "Đảo Tháp Chuông"]
const SECOND_ISLAND := Vector3(70, 0, 0)
const BRIDGE := Rect2(26, -2, 18, 4)
const RAMP_ANGLES := [30.0, 150.0]
const TOWER_RADIUS := 2.0
const TOWER_HEIGHT := 8.0
const RADII := [40.0, 28.0, 45.0]
const LANTERNS := [
	[Vector3(0, 0, 25), Vector3(23.8, 0, 7.7), Vector3(14.7, 0, -20.2),
		Vector3(-14.7, 0, -20.2), Vector3(-23.8, 0, 7.7)],
	[Vector3(0, 0, 20), Vector3(17, 0, -10), Vector3(-17, 0, -10),
		Vector3(70, 0, 20), Vector3(87, 0, -10), Vector3(53, 0, -10)],
	[Vector3(0, 6, 6), Vector3(18, 3, 10), Vector3(-18, 3, 10), Vector3(35, 0, -10),
		Vector3(-35, 0, -10), Vector3(20, 0, -35), Vector3(-20, 0, -35)]
]

static func radial(radius: float, degrees: float, height: float = 0.0) -> Vector3:
	var angle := deg_to_rad(degrees)
	return Vector3(cos(angle) * radius, height, sin(angle) * radius)

static func ring(count: int, radius: float, offset: float = 0.0, center: Vector3 = Vector3.ZERO) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in count:
		result.append(center + radial(radius, offset + 360.0 * i / count))
	return result

static func mote_points(night: int) -> Array[Vector3]:
	match night:
		1:
			var points := ring(8, 12)
			points.append_array(ring(16, 33))
			return points
		2:
			var points := ring(4, 10)
			points.append_array(ring(8, 22))
			points.append_array(ring(4, 10, 0, SECOND_ISLAND))
			points.append_array(ring(8, 22, 0, SECOND_ISLAND))
			return points
		_:
			var points := ring(18, 34)
			for angle in range(20, 161, 20):
				points.append(radial(18, angle, 3))
			points.append_array(ring(4, 5, 45, Vector3(0, 6, 0)))
			return points

static func shade_points(night: int) -> Array[Vector3]:
	match night:
		1:
			return ring(12, 37, 15)
		2:
			var points := ring(8, 26, 22.5)
			points.append_array(ring(8, 26, 22.5, SECOND_ISLAND))
			return points
		_:
			return ring(16, 43)

static func pads(night: int) -> Array[Dictionary]:
	if night == 2:
		var east := Vector3(20, 0, 18)
		var west := Vector3(50, 0, -18)
		return [
			{"pos": east, "vel": (SECOND_ISLAND - east).normalized() * 24 + Vector3.UP * 14},
			{"pos": west, "vel": -west.normalized() * 24 + Vector3.UP * 14}
		]
	if night == 3:
		return [{"pos": Vector3(0, 3, 13), "vel": Vector3(0, 12, -8)}]
	return []

static func charm_points(night: int) -> Array[Vector3]:
	if night == 2:
		return [Vector3(35, 0, 0)]
	if night == 3:
		return [Vector3(30, 0, 25), Vector3(-30, 0, 25)]
	return []

static func floor_surfaces(night: int, pos: Vector3) -> Array[float]:
	var horizontal := Vector2(pos.x, pos.z)
	var radius := horizontal.length()
	var result: Array[float] = []
	if radius <= RADII[night - 1]:
		result.append(0.0)
	if night == 2:
		if horizontal.distance_to(Vector2(70, 0)) <= 28 or (
			pos.x >= BRIDGE.position.x and pos.x <= BRIDGE.end.x
			and absf(pos.z) <= BRIDGE.size.y / 2
		):
			if result.is_empty():
				result.append(0.0)
	elif night == 3:
		if radius <= 8:
			result.append(6.0)
		if pos.z > 0 and radius >= 12 and radius <= 24:
			result.append(3.0)
		for angle in RAMP_ANGLES:
			var axis := Vector2(radial(1, angle).x, radial(1, angle).z)
			var along := horizontal.dot(axis)
			if along >= 24 and along <= 30 and absf(horizontal.cross(axis)) <= 1.5:
				result.append((30 - along) * 0.5)
	return result

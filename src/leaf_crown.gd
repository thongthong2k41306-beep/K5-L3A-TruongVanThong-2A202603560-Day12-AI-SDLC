extends RefCounted

# Build once. Each spray has folded leaves on either side of its stem.
static func build() -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1937
	for i in 360:
		var y := 1.0 - (i + 0.5) / 180.0
		var radius := sqrt(1.0 - y * y)
		var angle := i * 2.399963
		var normal := Vector3(radius * cos(angle), y, radius * sin(angle))
		var tangent := Vector3(-sin(angle), 0, cos(angle))
		var across := normal.cross(tangent)
		var spread := 0.42 + 0.048 * sin(angle * 3 + y * 5) + rng.randf_range(-0.035, 0.035)
		var root := normal * spread
		var axis := (tangent * rng.randf_range(-0.7, 0.7) + normal * 0.85 + Vector3.DOWN * 0.35).normalized()
		var tint := Color.WHITE.darkened(rng.randf_range(0.03, 0.34))
		for j in 5:
			var side := 1.0 if j % 2 == 0 else -1.0
			var start := root + axis * (j * 0.026)
			var tip := start + axis * 0.09 + across * side * (0.10 - j * 0.008)
			var mid := (start + tip) * 0.5
			var half_width := (tip - start).cross(normal + Vector3.UP * 0.32).normalized() * 0.034
			var spine := mid + normal * 0.015
			mesh.set_color(tint)
			for vertex in [start, mid + half_width, spine, start, spine, mid - half_width,
				spine, mid + half_width, tip, mid - half_width, spine, tip]:
				mesh.set_normal((normal + Vector3.UP * 0.48).normalized())
				mesh.add_vertex(vertex)
	mesh.index()
	return mesh.commit()

extends RefCounted

# One mesh for all brass inlays on a face, including the curved corners.
static func trace(surface: SurfaceTool, points: PackedVector3Array, width: float) -> void:
	var rings: Array[PackedVector3Array] = []
	for i in points.size():
		var along := (points[mini(i + 1, points.size() - 1)] - points[maxi(0, i - 1)]).normalized()
		var right := Vector3(-along.y, along.x, 0).normalized()
		var front := along.cross(right).normalized()
		var rim := PackedVector3Array()
		for side in 6:
			var phi := side * TAU / 6
			rim.append(points[i] + width * (cos(phi) * right + sin(phi) * front))
		rings.append(rim)
	for i in range(rings.size() - 1):
		for side in 6:
			var next := (side + 1) % 6
			for vertex in [rings[i][side], rings[i+1][side], rings[i+1][next],
				rings[i][side], rings[i+1][next], rings[i][next]]:
				surface.add_vertex(vertex)

static func panel() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	trace(s, PackedVector3Array([Vector3(0,0.30,0), Vector3(0.095,0.16,0), Vector3(0,0.02,0),
		Vector3(-0.095,0.16,0), Vector3(0,0.30,0)]), 0.012)
	for side in [-1,1]:
		var path := PackedVector3Array()
		for i in 29:
			var t := i / 28.0
			var a := t * TAU * 1.17 + 1.0
			var r := (1.0 - t * 0.87) * 0.115
			path.append(Vector3(side * (0.147 + cos(a) * r), -0.035 + sin(a) * r, 0))
		trace(s, path, 0.014)
		trace(s, PackedVector3Array([Vector3(side * 0.26,0.285,0), Vector3(side * 0.19,0.285,0),
			Vector3(side * 0.19,0.22,0), Vector3(side * 0.25,0.22,0)]), 0.011)
	s.generate_normals()
	s.index()
	return s.commit()

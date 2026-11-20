extends RefCounted

# Three slender stems with paired spikelets per instanced clump.
static func build() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stem := CylinderMesh.new()
	stem.radial_segments = 4
	stem.bottom_radius = 0.012
	stem.top_radius = 0.006
	var grain := SphereMesh.new()
	grain.radial_segments = 5
	grain.rings = 2
	for stalk in 3:
		var spin := Basis(Vector3.UP, stalk * 2.4)
		var h := 0.61 + 0.12 * stalk
		var offset := spin * Vector3(0.09, 0, 0)
		var tilt := spin * Basis(Vector3.FORWARD, 0.12 + 0.04 * stalk)
		var tip := offset + tilt.y * h
		s.append_from(stem,0,Transform3D(tilt * Basis.from_scale(Vector3(1,h * 0.5,1)), (tip + offset)*0.5))
		for j in 7:
			var side := -1.0 if j % 2 else 1.0
			var q := tip + tilt.y * (0.025 * j) + tilt.x * side * 0.019
			var blade := tilt * Basis(Vector3.FORWARD, side * 0.39)
			s.append_from(grain,0,Transform3D(blade * Basis.from_scale(Vector3(0.023,0.093-j*0.006,0.017)),q))
	return s.commit()

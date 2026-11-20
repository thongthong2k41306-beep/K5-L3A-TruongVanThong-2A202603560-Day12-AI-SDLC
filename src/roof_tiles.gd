extends RefCounted

# The same tiled surface fits the small lantern canopy and the pavilion.
static func build() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var color_rng := RandomNumberGenerator.new()
	color_rng.seed = 610
	for slope in [-1, 1]:
		for tile in 32:
			for row in 8:
				var color := Color("607777").darkened(color_rng.randf_range(0.0, 0.22))
				for rib in 4:
					var corners: Array[Vector3] = []
					for uv in [Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,1)]:
						var cross_tile: float = (rib + uv.x) / 4.0
						var x: float = (tile + cross_tile) / 16.0 - 1.0
						var eave: float = (row + uv.y * 1.08) / 8.0
						var y := 3.03 + 1.22 * pow(1.0 - minf(eave, 1.0), 1.55)
						y += 0.42 * pow(absf(x), 4) * eave * eave
						y += sin(cross_tile * PI) * 0.057 + uv.y * 0.036
						corners.append(Vector3(x * (2.51 + eave * 0.48), y, slope * eave * 2.17))
					var normal := (corners[1] - corners[0]).cross(corners[3] - corners[0]).normalized()
					if normal.y < 0:
						normal = -normal
					for index in [0, 1, 2, 0, 2, 3]:
						surface.set_normal(normal)
						surface.set_color(color)
						surface.add_vertex(corners[index])
	surface.index()
	return surface.commit()

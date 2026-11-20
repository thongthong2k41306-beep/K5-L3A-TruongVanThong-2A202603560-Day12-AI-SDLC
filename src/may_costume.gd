extends RefCounted

# Cross-sections are (horizontal radius, height, depth radius, forward offset).
static func tailored(parent: Node3D, sections: Array, material: Material, folds: float = 0.0) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 32
	for row in range(sections.size() - 1):
		for column in segments:
			for corner: Vector2i in [Vector2i(0,0), Vector2i(1,0), Vector2i(1,1), Vector2i(0,0), Vector2i(1,1), Vector2i(0,1)]:
				var profile: Vector4 = sections[row + corner.y]
				var angle := TAU * (column + corner.x) / segments
				var fluting := 1.0 + folds * cos(8.0 * angle)
				surface.set_uv(Vector2(float(column + corner.x) / segments, float(row + corner.y) / sections.size()))
				surface.add_vertex(Vector3(cos(angle) * profile.x * fluting, profile.y, sin(angle) * profile.z * fluting + profile.w))
	surface.generate_normals()
	surface.index()
	var piece := MeshInstance3D.new()
	piece.mesh = surface.commit()
	piece.material_override = material
	parent.add_child(piece)
	return piece

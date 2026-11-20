extends Node3D
const Simulation = preload("res://src/simulation.gd")
const MiniMap = preload("res://src/minimap.gd")
const Validation = preload("res://src/validation.gd")
const SkyShader = preload("res://src/island_sky.gdshader")
const GroundShader = preload("res://src/island_ground.gdshader")
const HaloShader = preload("res://src/light_halo.gdshader")
const FuelBarShader = preload("res://src/fuel_bar.gdshader")
const MeadowShader = preload("res://src/meadow.gdshader")
const ForestShader = preload("res://src/forest_surface.gdshader")
const LanternPaper = preload("res://src/lantern_paper.gdshader")
const LeafCrown = preload("res://src/leaf_crown.gd")
const Costume = preload("res://src/may_costume.gd")
const Carving = preload("res://src/carved_trim.gd")
const Plume = preload("res://src/grass_plume.gd")
var plume_mesh: ArrayMesh
var pavilion_sites: Array[Vector3] = []
var carved_panel: ArrayMesh
const RoofTiles = preload("res://src/roof_tiles.gd")
var leaf_mesh: ArrayMesh
var tile_mesh: ArrayMesh
const Layout = preload("res://src/night_layout.gd")
const Sound = preload("res://src/night_audio.gd")
const Leaderboard = preload("res://src/leaderboard.gd")
const ACTION_KEYS := {"left": KEY_A, "right": KEY_D, "forward": KEY_W, "backward": KEY_S,
	"jump": KEY_SPACE, "interact": KEY_E, "pulse": KEY_Q, "pause": KEY_ESCAPE, "dash": KEY_SHIFT}
const ACTION_LABELS := {"left": "Sang trái", "right": "Sang phải", "forward": "Tiến", "backward": "Lùi",
	"jump": "Nhảy", "interact": "Tương tác", "pulse": "Tỏa Sáng", "pause": "Tạm dừng", "dash": "Lướt"}
var sound: Node
var retry_button: Button
var wind_leaves: Array[MeshInstance3D] = []
var map_root: Node3D
var campaign_night := 1
var exploring := false
var exploration_seed := 0
var campaign_score := 0
var intro_screen: ColorRect
var intro_title: Label
var intro_line: Label
var next_button: Button
var night_label: Label
var cooldown_label: Label
var indicator: Label
var settings_screen: ColorRect
var mouse_sensitivity := 1.0
var accessible_palette := false
var reduced_motion := false
var large_text := false
var key_bindings: Dictionary = ACTION_KEYS.duplicate()
var key_buttons: Dictionary = {}
var rebind_action := ""
var keys_screen: ColorRect
var keys_status: Label
var leaderboard_screen: ColorRect
var leaderboard_rows: Label
var score_form: HBoxContainer
var score_name: LineEdit
var score_button: Button
var score_status: Label
var scent_indicator: Label
var help_keys: Label
var fuel_warning: Label
var latest_shade_id := ""
var spawn_notice_until := 0
var feedback_priority := 0
var leaderboard = Leaderboard.new()
var volume := 0.75
var settings := ConfigFile.new()
var settings_path := "user://settings.cfg"
var special_nodes: Dictionary = {}
var sky_material: ShaderMaterial
var mote_material: StandardMaterial3D
var mote_halo_mesh: QuadMesh
var mote_halo_material: ShaderMaterial
var sim = Simulation.new(2026)
var scenery_rng := RandomNumberGenerator.new()
var camera: Camera3D
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var may: Node3D
var character: Node3D
var cloak: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var mote_nodes: Dictionary = {}
var shade_nodes: Dictionary = {}
var shade_batches: Array[MultiMesh] = []
var lantern_nodes: Dictionary = {}
var hud: Control
var menu: ColorRect
var end_screen: ColorRect
var pause_screen: ColorRect
var hearts_label: Label
var carried_label: Label
var timer_label: Label
var score_label: Label
var objective_label: Label
var hint_label: Label
var feedback_label: Label
var end_title: Label
var end_description: Label
var progress_bar: ProgressBar
var minimap: Control
var lit_count := 0
var active := false
var paused := false
var yaw := 0.0
var pitch := 0.42
var visual_time := 0.0
var toast_time := 0.0
var pulse_ring: MeshInstance3D
var pulse_age := 5.0
var capture_path := ""
var capture_menu := false
var capture_frame := 0
var start_seed := 2026
var start_scenario: Dictionary = {}
var benchmark_mode := false

func _ready() -> void:
	scenery_rng.seed = 12
	if not benchmark_mode:
		_load_settings()
		get_viewport().msaa_3d = Viewport.MSAA_2X
	_setup_input()
	_build_environment()
	_build_island()
	_build_player()
	_build_camera()
	_build_ui()
	_apply_text_size()
	sound = Sound.new()
	add_child(sound)
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--capture" and i + 1 < args.size():
			capture_path = args[i + 1]
		if args[i] == "--capture-menu":
			capture_menu = true
		if args[i] == "--scenario" and i + 1 < args.size():
			var parser := JSON.new()
			if parser.parse(FileAccess.get_file_as_string(args[i + 1])) != OK:
				push_error("Invalid visual scenario")
				get_tree().quit(2)
				return
			var error := Validation.scenario(parser.data, sim.tuning)
			if not error.is_empty():
				printerr(error)
				get_tree().quit(2)
				return
			start_scenario = parser.data
	_sync_visuals(0)
	_update_camera(true)
	if not capture_path.is_empty() and not capture_menu:
		_start_game()

func _setup_input() -> void:
	var bindings := key_bindings.duplicate()
	bindings["restart"] = KEY_R
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var key := InputEventKey.new()
		key.physical_keycode = bindings[action]
		InputMap.action_add_event(action, key)
	if key_bindings.pause == KEY_ESCAPE and not key_bindings.values().has(KEY_P):
		var pause_key := InputEventKey.new()
		pause_key.physical_keycode = KEY_P
		InputMap.action_add_event("pause", pause_key)

func _input(event: InputEvent) -> void:
	if rebind_action.is_empty() or not event is InputEventKey or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var code: int = event.physical_keycode
	if code == 0:
		return
	for action in key_bindings:
		if action != rebind_action and key_bindings[action] == code:
			keys_status.text = "Phím đã dùng cho: " + ACTION_LABELS[action]
			return
	if code == KEY_R:
		keys_status.text = "R dùng để chơi lại. Hãy chọn phím khác."
		return
	key_bindings[rebind_action] = code
	rebind_action = ""
	keys_status.text = "Đã lưu phím."
	_save_bindings()

func _save_bindings() -> void:
	settings.set_value("game", "keys", key_bindings)
	_save_settings()
	_setup_input()
	_refresh_key_labels()

func _material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if emission > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

func _mesh(parent: Node3D, shape: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material
	node.position = pos
	parent.add_child(node)
	return node

func _surface(color: Color, kind: int) -> Material:
	if benchmark_mode:
		return _material(color)
	var surface := ShaderMaterial.new()
	surface.shader = ForestShader
	surface.set_shader_parameter("base", color)
	surface.set_shader_parameter("surface_kind", kind)
	surface.set_shader_parameter("grain_map", preload("res://src/art/bark.jpg") if kind == 0 else (
		preload("res://src/art/timber.jpg") if kind == 3 else preload("res://src/art/slate.jpg")))
	return surface

func _canopy(tree: Node3D, pos: Vector3, dimensions: Vector3, material: Material) -> Node3D:
	if benchmark_mode:
		return _sphere(tree, pos, dimensions, material)
	if leaf_mesh == null:
		leaf_mesh = LeafCrown.build()
	var crown := _mesh(tree, leaf_mesh, pos, material)
	crown.scale = dimensions
	return crown

func _tiles(parent: Node3D) -> MeshInstance3D:
	if tile_mesh == null:
		tile_mesh = RoofTiles.build()
	var glaze := _material(Color.WHITE)
	glaze.vertex_color_use_as_albedo = true
	glaze.vertex_color_is_srgb = true
	glaze.cull_mode = BaseMaterial3D.CULL_DISABLED
	glaze.roughness = 0.70
	return _mesh(parent, tile_mesh, Vector3.ZERO, glaze)

func _inlay(parent: Node3D, pos: Vector3, scale_value: Vector3, yaw_angle: float, gold: Material) -> void:
	if carved_panel == null:
		carved_panel = Carving.panel()
	var detail := _mesh(parent, carved_panel, pos, gold)
	detail.scale = scale_value
	detail.rotation.y = yaw_angle

func _sphere(parent: Node3D, pos: Vector3, scale_value: Vector3, material: Material) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 12
	sphere.rings = 6
	var node := _mesh(parent, sphere, pos, material)
	node.scale = scale_value
	return node

func _cylinder(parent: Node3D, pos: Vector3, bottom: float, top: float, height: float, material: Material, sides: int = 16) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = bottom
	cylinder.top_radius = top
	cylinder.height = height
	cylinder.radial_segments = sides
	return _mesh(parent, cylinder, pos, material)

func _box(parent: Node3D, pos: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = dimensions
	return _mesh(parent, box, pos, material)

func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	var environment := Environment.new()
	sky_material = ShaderMaterial.new()
	sky_material.shader = SkyShader
	if not benchmark_mode:
		sky_material.set_shader_parameter("painted", true)
		sky_material.set_shader_parameter("mountains", preload("res://src/art/mountains.jpg"))
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("859ac0")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("254957")
	environment.fog_light_energy = 0.7
	environment.fog_density = 0.006
	environment.fog_sky_affect = 0.15
	world_environment.environment = environment
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, -38, 0)
	sun.light_color = Color("b3d6ef")
	sun.light_energy = 0.85
	if not benchmark_mode:
		environment.ambient_light_color = Color("c6d7e9")
		sun.light_color = Color("ffe5c1")
		sun.light_energy = 0.76
		sun.rotation_degrees = Vector3(-33, -48, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 34.0
	add_child(sun)
	if not benchmark_mode:
		return
	var cloud_material := _material(Color("333b5d"))
	for i in range(42):
		var angle := i * TAU / 42
		var radius := scenery_rng.randf_range(40, 65)
		var cloud := _sphere(self, Vector3(sin(angle) * radius, -4.5 + scenery_rng.randf_range(-2, 1), cos(angle) * radius), Vector3(13, 3, 8), cloud_material)
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_island() -> void:
	if is_instance_valid(map_root):
		map_root.hide()
		map_root.queue_free()
	map_root = Node3D.new()
	add_child(map_root)
	pavilion_sites.clear()
	if not benchmark_mode:
		match sim.night:
			1:
				pavilion_sites.append(Vector3(-10, 0, -17))
				if sim.exploration:
					pavilion_sites.append(Vector3(36, 0, -30))
			2:
				pavilion_sites.append_array([Vector3(14, 0, 8), Layout.SECOND_ISLAND + Vector3(-13, 0, -8)])
			3:
				pavilion_sites.append(Layout.radial(18, 64, 3))
		for site in pavilion_sites:
			_build_pavilion(site)
	lantern_nodes.clear()
	special_nodes.clear()
	wind_leaves.clear()
	var ground := ShaderMaterial.new()
	ground.shader = GroundShader
	if not benchmark_mode:
		ground.set_shader_parameter("painted", true)
		ground.set_shader_parameter("meadow", preload("res://src/art/meadow.jpg"))
	var radius: float = sim.island_radius
	_cylinder(map_root, Vector3(0, -0.7, 0), radius - 1.8, radius, 1.4, ground, 80)
	if sim.night == 2:
		_cylinder(map_root, Layout.SECOND_ISLAND + Vector3(0, -0.7, 0), 26.2, 28, 1.4, ground, 80)
		for i in 36:
			_box(map_root, Vector3(26.25 + i * 0.5, -0.10, 0), Vector3(0.48, 0.2, 4), _material(Color("987a4d").darkened((i % 3) * 0.09)))
	elif sim.night == 3:
		_build_terraces(ground)
		var leaf := _material(Color("cc986a"))
		for i in 20:
			var node := _box(map_root, Vector3.ZERO, Vector3(0.24, 0.04, 0.09), leaf)
			node.hide()
			wind_leaves.append(node)
	for pad in Layout.pads(sim.night):
		_cylinder(map_root, pad.pos + Vector3(0, 0.025, 0), 1, 1, 0.05, _material(Color("53a89e"), 0.35), 24)
	mote_material = _material(Color("ffd075"), 1.05)
	mote_halo_mesh = QuadMesh.new()
	mote_halo_mesh.size = Vector2(0.84, 0.84)
	mote_halo_material = ShaderMaterial.new()
	mote_halo_material.shader = HaloShader
	_cylinder(map_root, Vector3(0, -3, 0), radius * 0.72, radius - 1.8, 3.4, _material(Color("303947")), 40)
	_cylinder(map_root, Vector3(0, -7.2, 0), 3, radius * 0.72, 5, _material(Color("252d40")), 24)
	if benchmark_mode:
		_cylinder(map_root, Vector3(0, 0.015, 0), 4, 4, 0.025, _material(Color("6b7060")), 36)
	var path_material := _surface(Color("74746a"), 2)
	var rock_material := _surface(Color("56616a"), 1)
	var trunk_material := _surface(Color("5f4c4b"), 0)
	var foliage := [
		_material(Color("174d45")), _material(Color("28785f")), _material(Color("4e9570"))
	]
	if not benchmark_mode:
		foliage = []
		for shade in [Color("4c6549"), Color("658055"), Color("859758")]:
			var leaves := _material(shade)
			leaves.vertex_color_use_as_albedo = true
			leaves.cull_mode = BaseMaterial3D.CULL_DISABLED
			foliage.append(leaves)
	for lantern in sim.lanterns if sim.night == 1 else []:
		for j in range(4, 22, 2):
			var direction: Vector3 = lantern.pos.normalized()
			var stone := _cylinder(map_root, direction * j + Vector3(0, 0.035, 0), 0.58, 0.65, 0.06, path_material, 7)
			stone.scale.z = 0.7
			stone.rotation.y = scenery_rng.randf() * TAU
	var grass_material := _material(Color("467765"))
	var grass_mesh := CylinderMesh.new()
	grass_mesh.bottom_radius = 0.13
	grass_mesh.top_radius = 0
	grass_mesh.height = 0.3
	grass_mesh.radial_segments = 3
	grass_mesh.material = grass_material
	var grass := MultiMesh.new()
	grass.transform_format = MultiMesh.TRANSFORM_3D
	grass.mesh = grass_mesh
	grass.instance_count = 105
	var tree_count := 48 if sim.exploration else 29
	var rock_count := 30 if sim.exploration else 22
	var grass_count := 155 if sim.exploration else 105
	grass.instance_count = grass_count
	for i in range(tree_count + rock_count + grass_count):
		var angle := scenery_rng.randf() * TAU
		var prop_radius := scenery_rng.randf_range(9, radius - 2)
		var pos := Vector3(sin(angle) * prop_radius, 0, cos(angle) * prop_radius)
		if i < tree_count:
			var center := Layout.SECOND_ISLAND if sim.night == 2 and i % 2 == 1 else Vector3.ZERO
			var tree_radius := radius - scenery_rng.randf_range(2, 9)
			var tree_pos := center + Vector3(sin(angle) * tree_radius, 0, cos(angle) * tree_radius)
			# Keep lantern approaches and the narrow bridge easy to read.
			var near_lantern: bool = sim.lanterns.any(func(lantern: Dictionary) -> bool: return Simulation.horizontal(tree_pos, lantern.pos) < 4)
			if not near_lantern and not (sim.night == 2 and absf(tree_pos.z) < 5 and tree_pos.x > 21 and tree_pos.x < 49):
				_build_forest_tree(tree_pos, trunk_material, foliage)
		elif i < tree_count + rock_count:
			var stone := _sphere(map_root, pos + Vector3(0, 0.2, 0), Vector3(scenery_rng.randf_range(0.6, 1.5), 0.7, 0.8), rock_material)
			stone.rotation.y = angle
		else:
			grass.set_instance_transform(i - tree_count - rock_count, Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.15, 0)))
	var field := MultiMeshInstance3D.new()
	field.multimesh = grass
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	map_root.add_child(field)
	field.visible = benchmark_mode
	if sim.night == 1 and not benchmark_mode:
		_build_ancient_tree(Vector3(11, 0, -25), trunk_material, foliage)
		_build_meadow(Vector3.ZERO, radius, 2800 if sim.exploration else 1550)
		for i in 5:
			var grove_angle := 54.0 + i * 72.0
			_build_forest_tree(Layout.radial(21, grove_angle), trunk_material, foliage)
			_build_forest_tree(Layout.radial(25, grove_angle + 8), trunk_material, foliage)
			_build_glade(Layout.radial(14, grove_angle), foliage[1])
		_build_boulder(Vector3(10, 0, -10), 4.2, rock_material)
		_build_boulder(Vector3(-16, 0, -9), 3.4, rock_material)
		if sim.exploration:
			for angle in [20, 110, 205, 280]:
				_build_boulder(Layout.radial(47, angle), 4.6, rock_material)
	elif not benchmark_mode:
		_build_meadow(Vector3.ZERO, radius, 1250)
		if sim.night == 2:
			_build_meadow(Layout.SECOND_ISLAND, radius, 1250)
			_build_ancient_tree(Layout.SECOND_ISLAND + Vector3(4, 0, -20), trunk_material, foliage)
			_build_boulder(Vector3(10, 0, -13), 3.3, rock_material)
		else:
			_build_ancient_tree(Vector3(-8, 0, -29), trunk_material, foliage)
			_build_boulder(Layout.radial(21, 104, 3), 3.6, rock_material)
	for lantern in sim.lanterns:
		_create_lantern(lantern)
	pulse_ring = _mesh(map_root, TorusMesh.new(), Vector3.ZERO, _material(Color("ffd286"), 1.7))
	pulse_ring.visible = false

func _build_meadow(center: Vector3, radius: float, count: int) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 15:
		var theta := i * 2.399963
		var side := Vector3(cos(theta), 0, sin(theta))
		var toward := Vector3(-side.z, 0, side.x)
		var patch := toward * (0.025 + i * 0.02)
		var height := 0.16 + (i % 7) * 0.069
		var lean := 0.12 + (i % 4) * 0.075
		for step in 4:
			var a := step / 4.0
			var b := (step + 1) / 4.0
			var p := patch + toward * lean * a * a + Vector3.UP * height * (1.3 * a - 0.3 * a * a)
			var q := patch + toward * lean * b * b + Vector3.UP * height * (1.3 * b - 0.3 * b * b)
			var half_width := 0.010 + 0.003 * (i % 5)
			var width_a := side * half_width * (1.0 - a * a)
			var width_b := side * half_width * (1.0 - b * b)
			for vertex in [[p - width_a, Vector2(0, a)], [p + width_a, Vector2(1, a)], [q + width_b, Vector2(1, b)],
				[p - width_a, Vector2(0, a)], [q + width_b, Vector2(1, b)], [q - width_b, Vector2(0, b)]]:
				surface.set_uv(vertex[1])
				surface.add_vertex(vertex[0])
	surface.generate_normals()
	var blade_material := ShaderMaterial.new()
	blade_material.shader = MeadowShader
	_add_meadow_instances(surface.commit(), blade_material, center, radius, count)
	if plume_mesh == null:
		plume_mesh = Plume.build()
	var awns := _material(Color("b6ae74"))
	_add_meadow_instances(plume_mesh, awns, center, radius, count / 8, true)
	var flower := SurfaceTool.new()
	flower.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stalk := CylinderMesh.new()
	stalk.height = 0.39
	stalk.top_radius = 0.008
	stalk.bottom_radius = 0.013
	stalk.radial_segments = 5
	flower.append_from(stalk, 0, Transform3D(Basis.IDENTITY, Vector3.UP * 0.195))
	var petal := SphereMesh.new()
	petal.radial_segments = 7
	petal.rings = 3
	for i in 5:
		var angle := TAU * i / 5.0
		var tilt := Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, -0.27)
		var tip := Vector3(sin(angle) * 0.049, 0.39, cos(angle) * 0.049)
		flower.append_from(petal, 0, Transform3D(tilt * Basis.from_scale(Vector3(0.068, 0.027, 0.11)), tip))
	var petals := _material(Color("b9b595"))
	petals.vertex_color_use_as_albedo = true
	var wildflower := flower.commit()
	# Tint the stem green and the petals warm ivory in this shared flower mesh.
	var arrays := wildflower.surface_get_arrays(0)
	var tints := PackedColorArray()
	for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		tints.append(Color("4a7a41") if Vector2(vertex.x, vertex.z).length() < 0.015 else Color("fff4d8"))
	arrays[Mesh.ARRAY_COLOR] = tints
	wildflower = ArrayMesh.new()
	wildflower.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_add_meadow_instances(wildflower, petals, center, radius, count / 9, true)

func _add_meadow_instances(mesh: Mesh, material: Material, center: Vector3, radius: float, count: int, flowers: bool = false) -> void:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = count
	for i in count:
		var extent := 16.0 if i % 2 == 0 else radius - 1.1
		var pos := center + Layout.radial(sqrt(scenery_rng.randf_range(0.045, 1)) * extent, scenery_rng.randf_range(0, 360))
		for site in pavilion_sites:
			var local := (pos - site).rotated(Vector3.UP,-PI/8)
			if absf(local.x) < 2.72 and absf(local.z) < 2.16:
				local.z = signf(local.z) * (2.27 + 0.14 * (i % 4))
				pos = site + local.rotated(Vector3.UP,PI/8)
		var s := scenery_rng.randf_range(0.46, 1.65)
		var size := Vector3.ONE * s
		if sim.night == 3:
			var levels := Layout.floor_surfaces(3, pos)
			if not levels.is_empty():
				pos.y = levels.max()
		var patch := 0.5 + 0.5 * sin(pos.x * 0.55 + cos(pos.z * 0.3)) * sin(pos.z * 0.64)
		if not flowers:
			size *= Vector3(1.10, 0.70 + patch * 1.55, 1.10)
		instances.set_instance_transform(i, Transform3D(Basis(Vector3.UP, scenery_rng.randf() * TAU).scaled(size), pos))
		instances.set_instance_color(i, [Color("c4ce89"), Color("81ad8e"), Color("91cc85"), Color("dee5a6")][i % 4])
	var field := MultiMeshInstance3D.new()
	field.multimesh = instances
	field.material_override = material
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	map_root.add_child(field)

func _branch(parent: Node3D, start: Vector3, finish: Vector3, thick: float, tip: float, material: Material) -> void:
	var direction := finish - start
	var piece := _cylinder(parent, (start + finish) * 0.5, thick, tip, direction.length(), material, 9)
	piece.quaternion = Quaternion(Vector3.UP, direction.normalized())

func _build_ancient_tree(pos: Vector3, bark: Material, foliage: Array) -> void:
	var tree := Node3D.new()
	map_root.add_child(tree)
	tree.position = pos
	var bend := Vector3(-0.7, 4.0, 0.2)
	var crown := Vector3(0.0, 9.6, -0.5)
	_branch(tree, Vector3.ZERO, bend, 1.65, 0.98, bark)
	_branch(tree, bend, Vector3(-0.5, 7.2, -0.3), 1.08, 0.70, bark)
	_branch(tree, Vector3(-0.5, 6.92, -0.3), crown, 0.74, 0.42, bark)
	_sphere(tree, bend, Vector3(1.92,1.62,1.91), bark)
	for i in 9:
		var angle := i * 137.5
		var root := Layout.radial(3.6 + (i % 3) * 0.6, angle, 0.07)
		var shoulder := Layout.radial(1.65, angle, 0.78)
		_branch(tree, shoulder, root, 0.47, 0.04, bark)
		_branch(tree, Vector3.UP * 2.6, shoulder, 0.62, 0.34, bark)
		var outer := Layout.radial(3.8 + (i % 3) * 0.55, angle, 8.4 + (i % 4) * 0.65)
		var fork := Layout.radial(2, angle, 7.2)
		_branch(tree, bend + Vector3.UP * (0.6 + i % 3), fork, 0.41, 0.30, bark)
		_branch(tree, fork, outer, 0.32, 0.08, bark)
		for leaf in 3:
			var patch := outer + Layout.radial(0.7 + leaf * 0.7, angle + (leaf - 1) * 46, 0.7 + leaf * 0.33)
			var canopy := _canopy(tree, patch, Vector3(4.5, 1.7 + leaf * 0.38, 4.3), foliage[(leaf + i) % foliage.size()])
			canopy.rotation.y = deg_to_rad(angle)
	_canopy(tree, crown + Vector3.UP * 1.1, Vector3(7.6, 3.3, 7.4), foliage[2])

func _build_boulder(pos: Vector3, width: float, material: Material) -> void:
	var rock := _sphere(map_root, pos + Vector3.UP * width * 0.25, Vector3(width, width * 0.70, width * 0.82), material)
	rock.rotation = Vector3(0.3, scenery_rng.randf() * TAU, 0.24)

func _build_pavilion(pos: Vector3) -> void:
	var pavilion := Node3D.new()
	map_root.add_child(pavilion)
	pavilion.position = pos
	pavilion.rotation.y = PI / 8
	var stone := _surface(Color("69746d"), 2)
	var wood := _surface(Color("785644"), 3)
	var brass := _material(Color("ae834f"))
	brass.metallic = 0.45
	brass.roughness = 0.45
	var lacquer := _material(Color("743e32"))
	_box(pavilion, Vector3(0, 0.10, 0), Vector3(5.1, 0.2, 4.0), stone)
	for x in [-2.0, 2.0]:
		for z in [-1.4, 1.4]:
			_cylinder(pavilion, Vector3(x, 1.53, z), 0.19, 0.15, 2.85, wood, 8)
			_cylinder(pavilion, Vector3(x, 0.30, z), 0.27, 0.24, 0.26, stone, 8)
	_box(pavilion, Vector3(0, 2.89, 0), Vector3(5.0, 0.24, 3.75), wood)
	_tiles(pavilion)
	for side in [-1, 1]:
		for end in [-1, 1]:
			_branch(pavilion, Vector3(end * 2.04, 2.88, side * 1.73),
				Vector3(end * 2.04, 4.16, 0), 0.095, 0.08, wood)
			_branch(pavilion, Vector3(end * 2.04, 2.32, side * 1.4),
				Vector3(end * 1.38, 2.87, side * 1.4), 0.072, 0.09, wood)
	_branch(pavilion, Vector3(-2.62, 4.27, 0), Vector3(2.62, 4.27, 0), 0.12, 0.12, wood)
	for end in [-1,1]:
		_branch(pavilion, Vector3(end * 2.48,4.26,0), Vector3(end * 2.76,4.37,0), 0.12,0.085,brass)
		_branch(pavilion, Vector3(end * 2.74,4.36,0), Vector3(end * 2.91,4.61,0), 0.083,0.019,brass)
		for side in [-1,1]:
			_branch(pavilion, Vector3(end * 2.65,3.30,side * 2.07), Vector3(end * 2.97,3.48,side * 2.18), 0.073,0.057,brass)
			_branch(pavilion, Vector3(end * 2.94,3.47,side * 2.17), Vector3(end * 3.09,3.69,side * 2.22), 0.062,0.01,brass)
			_box(pavilion, Vector3(end * 2.0,2.68,side * 1.4), Vector3(0.44,0.16,0.44), lacquer)
			_box(pavilion, Vector3(end * 2.0,2.80,side * 1.4), Vector3(0.67,0.12,0.51), wood)
			for y in [0.55,1.05]:
				_box(pavilion, Vector3(end * 2.0,y,side * 0.73), Vector3(0.085,0.075,1.42), wood)
			for rail in 4:
				_box(pavilion, Vector3(end * 2,0.80,side * (0.22 + rail * 0.31)), Vector3(0.047,0.47,0.047), lacquer)
	for side in [-1,1]:
		_box(pavilion, Vector3(0,2.77,side * 1.67), Vector3(4.32,0.23,0.11), lacquer)
		for column in range(-4,5):
			_inlay(pavilion,Vector3(column*0.48,2.73,side*1.737),Vector3(0.81,0.46,0.81),0.0 if side>0 else PI,brass)
		var pendant := Node3D.new()
		pavilion.add_child(pendant)
		pendant.position = Vector3(side * 1.68,2.38,1.47)
		_branch(pendant,Vector3.UP*0.35,Vector3.UP*0.16,0.012,0.012,brass)
		_sphere(pendant,Vector3.ZERO,Vector3(0.34,0.42,0.34),_material(Color("ff934b"),0.48))
		for cap_y in [-0.17,0.0,0.17]:
			var band := 0.171 if cap_y == 0.0 else 0.11
			_cylinder(pendant,Vector3.UP*cap_y,band,band,0.024,brass)
		_cylinder(pendant,Vector3.DOWN*0.31,0.036,0.019,0.21,lacquer)

func _build_glade(pos: Vector3, stems: Material) -> void:
	var petals := _material(Color("9c9ddd"), 0.12)
	for i in 7:
		var tuft := pos + Layout.radial(0.35 + i * 0.22, i * 137.5)
		var height := 0.27 + i % 3 * 0.11
		var stem := _cylinder(map_root, tuft + Vector3.UP * height * 0.5, 0.032, 0.018, height, stems, 4)
		stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var flower := _sphere(map_root, tuft + Vector3.UP * height, Vector3(0.23, 0.11, 0.23), petals)
		flower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_forest_tree(pos: Vector3, bark: Material, foliage: Array) -> void:
	var tree := Node3D.new()
	map_root.add_child(tree)
	tree.position = pos
	tree.rotation.y = scenery_rng.randf() * TAU
	var height := scenery_rng.randf_range(4.7, 7.1)
	var trunk := _cylinder(tree, Vector3(0, height * 0.42, 0), 0.42, 0.14, height * 0.84, bark, 7)
	trunk.rotation.z = 0.05
	for i in 3:
		var angle := TAU * i / 3.0
		var branch := _cylinder(tree, Layout.radial(0.72, rad_to_deg(angle), height * 0.55), 0.14, 0.06, 2.2, bark, 5)
		branch.rotation = Vector3(sin(angle) * 0.70, 0, -cos(angle) * 0.70)
		var canopy := _canopy(tree, Layout.radial(1.26, rad_to_deg(angle), height * (0.67 + i * 0.055)),
			Vector3(3.8, 2.2, 3.3), foliage[i])
		canopy.rotation.y = angle
	_canopy(tree, Vector3(0, height * 0.92, 0), Vector3(4.0, 2.55, 3.5), foliage[1])
	for i in 3:
		var fern := _canopy(tree, Layout.radial(0.9 + i * 0.32, 110 * i, 0.19), Vector3(0.85, 0.48, 1.2), foliage[i]) as MeshInstance3D
		fern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_terraces(ground: Material) -> void:
	var cliff := _material(Color("3e4c5b"))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 48:
		var start := i * 180.0 / 48
		var finish := (i + 1) * 180.0 / 48
		var a := Layout.radial(12, start, 3)
		var b := Layout.radial(24, start, 3)
		var c := Layout.radial(24, finish, 3)
		var d := Layout.radial(12, finish, 3)
		for corner in [a, b, c, a, c, d, b, b - Vector3.UP * 3, c - Vector3.UP * 3,
			b, c - Vector3.UP * 3, c, d, d - Vector3.UP * 3, a - Vector3.UP * 3, d, a - Vector3.UP * 3, a]:
			surface.add_vertex(corner)
	surface.generate_normals()
	_mesh(map_root, surface.commit(), Vector3.ZERO, ground)
	_cylinder(map_root, Vector3(0, 5.7, 0), 8, 8, 0.6, cliff, 56)
	for angle in [45, 135, 225, 315]:
		_cylinder(map_root, Layout.radial(7, angle, 2.7), 0.22, 0.18, 5.4, cliff, 6)
	_cylinder(map_root, Vector3(0, 10, 0), 2, 2, 8, _material(Color("77717a")), 20)
	_cylinder(map_root, Vector3(0, 14.3, 0), 2.5, 0, 0.6, _material(Color("315e58")), 20)
	if not benchmark_mode:
		var masonry := _surface(Color("656c72"),2)
		var lacquer := _surface(Color("785644"),3)
		var bronze := _material(Color("977a4c"))
		bronze.metallic = 0.48
		for level in [7.0,9.4,11.8]:
			_cylinder(map_root,Vector3.UP*level,2.12,2.06,0.22,masonry,24)
		for face in 8:
			var turn := face*TAU/8
			var beam := _box(map_root,Vector3(sin(turn)*1.95,10,cos(turn)*1.95),Vector3(0.16,7.8,0.20),lacquer)
			beam.rotation.y = turn
		var tower := Node3D.new()
		tower.position.y = 14.1
		map_root.add_child(tower)
		_tiles(tower)
		for x in [-1.7,1.7]:
			for z in [-1.25,1.25]:
				_cylinder(tower,Vector3(x,1.51,z),0.17,0.13,3.05,lacquer)
		_branch(tower,Vector3(-1.79,2.76,0),Vector3(1.79,2.76,0),0.15,0.15,lacquer)
		_cylinder(tower,Vector3.UP*1.88,0.42,0.23,0.94,bronze,24)
		_cylinder(tower,Vector3.UP*1.42,0.51,0.41,0.15,bronze,24)
		_branch(tower,Vector3.UP*2.35,Vector3.UP*2.76,0.042,0.042,bronze)
	for angle in Layout.RAMP_ANGLES:
		var axis := Layout.radial(1, angle)
		var ramp := _box(map_root, axis * 27 + Vector3(0, 1.42, 0), Vector3(3, 0.15, sqrt(45.0)), cliff)
		ramp.look_at(ramp.position + axis * 6 - Vector3.UP * 3)

func _create_lantern(lantern: Dictionary) -> void:
	var root := Node3D.new()
	root.position = lantern.pos
	map_root.add_child(root)
	var wood := _surface(Color("704c43"), 3)
	var paper: Material = _material(Color("736761"), 0.15)
	if not benchmark_mode:
		var silk := ShaderMaterial.new()
		silk.shader = LanternPaper
		paper = silk
	var shell := Node3D.new()
	shell.position.y = 2.55
	root.add_child(shell)
	var style := 1 if benchmark_mode else (int(str(lantern.id).substr(1)) - 1) % 3
	var body := _lantern_mesh(root, shell, style, wood, paper)
	var tear := Node3D.new()
	shell.add_child(tear)
	var rip_material := _material(Color("201b24"))
	for direction in [-1, 1]:
		for i in 3:
			var rip_depth: float = [0.58, 0.51, 0.43][style]
			var rip := _box(tear, Vector3(-0.10 + i * 0.09, 0.26 - i * 0.17, direction * rip_depth),
				Vector3(0.075 + i * 0.014, 0.25, 0.028), rip_material)
			rip.rotation.z = -0.55 if i % 2 == 0 else 0.42
	var light := OmniLight3D.new()
	light.position.y = 2.8
	light.light_color = Color("ffba65")
	light.omni_range = 12
	light.light_energy = 0.1
	root.add_child(light)
	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2(4.3, 4.3)
	var halo_material := ShaderMaterial.new()
	halo_material.shader = HaloShader
	halo_material.set_shader_parameter("glow_color", Color(1.0, 0.54, 0.18, 0.68))
	var halo := _mesh(root, halo_mesh, Vector3(0, 2.55, 0), halo_material)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.visible = false
	var marker := Label3D.new()
	marker.text = lantern.id + " · 0/10"
	marker.font_size = 40
	marker.pixel_size = 0.008
	marker.position.y = 4.3
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.modulate = Color("ffe4b0")
	root.add_child(marker)
	var bar_mesh := QuadMesh.new()
	bar_mesh.size = Vector2(1.7, 0.16)
	var bar_material := ShaderMaterial.new()
	bar_material.shader = FuelBarShader
	var bar := _mesh(root, bar_mesh, Vector3(0, 3.88, 0), bar_material)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = float(sim.tuning.safe_radius) - 0.06
	ring_mesh.outer_radius = float(sim.tuning.safe_radius)
	var ring := _mesh(root, ring_mesh, Vector3(0, 0.045, 0), _material(Color("dcb976"), 0.4))
	ring.scale.y = 0.04
	ring.visible = false
	lantern_nodes[lantern.id] = {"root": root, "body": body, "shell": shell, "tear": tear, "style": style,
		"light": light, "marker": marker, "ring": ring, "halo": halo, "bar": bar, "bar_material": bar_material}

func _lantern_mesh(root: Node3D, shell: Node3D, style: int, wood: Material, paper: Material) -> MeshInstance3D:
	var gold := _material(Color("ba9560"))
	if not benchmark_mode:
		gold.metallic = 0.62
		gold.roughness = 0.38
	var stone := _surface(Color("686d66"), 2)
	_cylinder(root, Vector3(0, 0.10, 0), 0.98, 0.81, 0.20, stone, 8)
	if not benchmark_mode:
		_cylinder(root,Vector3.UP*0.215,0.74,0.68,0.085,stone,8)
		_cylinder(root,Vector3.UP*0.265,0.64,0.63,0.035,gold,8)
	match style:
		0: # Lantern on a wooden cantilever.
			_box(root, Vector3(-0.82, 1.73, 0), Vector3(0.22, 3.19, 0.29), wood)
			_branch(root, Vector3(-0.82, 2.45, 0), Vector3(0.52, 3.43, 0), 0.09, 0.06, wood)
			_box(root, Vector3(-0.31, 3.46, 0), Vector3(1.85, 0.20, 0.22), wood)
			var canopy := _tiles(root)
			canopy.scale = Vector3(0.37, 0.38, 0.40)
			canopy.position = Vector3(-0.31, 2.32, 0)
			_cylinder(root, Vector3(0, 3.19, 0), 0.025, 0.025, 0.34, gold, 8)
			var globe := _sphere(shell, Vector3.ZERO, Vector3(1.19, 1.08, 1.19), paper)
			for y in [-0.39, 0.0, 0.39]:
				var band := 0.60 * sqrt(1.0 - (y / 0.54) ** 2)
				_cylinder(shell, Vector3(0, y, 0), band, band, 0.024, gold, 20)
			for side in 8:
				var face := side * TAU / 8
				_inlay(shell,Vector3(sin(face)*0.594,-0.07,cos(face)*0.594),Vector3(0.67,0.68,0.52),face,gold)
			_cylinder(shell,Vector3.DOWN*0.48,0.255,0.29,0.085,gold,24)
			_cylinder(shell, Vector3(0, -0.64, 0), 0.046, 0.074, 0.21, _material(Color("a34532")), 8)
			return globe
		1: # Bronze shrine lamp with curved corner finials.
			_box(root, Vector3(0, 0.23, 0), Vector3(1.42, 0.20, 1.42), wood)
			_cylinder(root, Vector3(0, 1.11, 0), 0.29, 0.20, 1.70, wood, 8)
			_box(root, Vector3(0, 1.93, 0), Vector3(1.35, 0.16, 1.35), gold)
			var box := _box(shell, Vector3.ZERO, Vector3(1.0, 1.14, 1.0), paper)
			for x in [-0.51, 0.51]:
				for z in [-0.51, 0.51]:
					_cylinder(shell, Vector3(x, 0, z), 0.035, 0.035, 1.17, wood, 6)
			if not benchmark_mode:
				var bronze := _material(Color("544c45"))
				bronze.metallic = 0.42
				_cylinder(root,Vector3.UP*0.57,0.57,0.39,0.60,bronze,4).rotation.y = PI/4
				var plinth := _box(root,Vector3.UP*1.12,Vector3(0.65,0.78,0.65),bronze)
				for trim_y in [0.75,1.48,1.66]:
					_box(root,Vector3.UP*trim_y,Vector3(0.78,0.075,0.78),gold)
				for face in 4:
					var turn := face * PI * 0.5
					_inlay(plinth,Vector3(sin(turn)*0.333,-0.09,cos(turn)*0.333),Vector3.ONE*1.03,turn,gold)
					var panel := Node3D.new()
					shell.add_child(panel)
					panel.rotation.y = face * PI * 0.5
					for side in [-1, 1]:
						var corner := Vector3(side * 0.48, 0.50, 0.512)
						_branch(panel, corner + Vector3.DOWN * 0.27, corner + Vector3.LEFT * side * 0.27, 0.019, 0.019, gold)
					_box(panel, Vector3(0, -0.42, 0.514), Vector3(0.98, 0.032, 0.024), gold)
					_inlay(panel,Vector3(0,-0.21,0.52),Vector3.ONE*0.7,0,gold)
			var roof := _cylinder(root, Vector3(0, 3.39, 0), 1.18, 0.16, 0.48, _material(Color("375e62")), 4)
			roof.rotation.y = PI / 4
			for angle in [45, 135, 225, 315]:
				_branch(root, Layout.radial(0.82, angle, 3.15), Layout.radial(1.26, angle, 3.39), 0.075, 0.015, gold)
			_sphere(root, Vector3.UP * 3.72, Vector3(0.15, 0.27, 0.15), gold)
			return box
		_: # Lotus lamp with layered metal petals.
			_cylinder(root, Vector3(0, 1.07, 0), 0.24, 0.13, 1.84, gold, 12)
			_cylinder(root, Vector3(0, 2.0, 0), 0.25, 0.66, 0.29, wood, 10)
			var bud := _sphere(shell, Vector3(0, 0.11, 0), Vector3(0.89, 1.17, 0.89), paper)
			var petal_material := _material(Color("aabc91"))
			petal_material.metallic = 0.48
			petal_material.roughness = 0.38
			for i in 7:
				var angle := 360.0 * i / 7
				var petal := _sphere(shell, Layout.radial(0.60, angle, -0.21), Vector3(0.38, 0.14, 0.88), petal_material)
				petal.rotation = Vector3(deg_to_rad(-22.0), deg_to_rad(90.0 - angle), 0)
				var vein_start := Layout.radial(0.34,angle,-0.235)
				_branch(shell,vein_start,Layout.radial(0.90,angle,-0.05),0.023,0.008,gold)
			for y in [0.46,0.54,1.79,1.86]:
				_cylinder(root,Vector3.UP*y,0.24,0.24,0.034,gold,20)
			_sphere(shell, Vector3.UP * 0.76, Vector3(0.12, 0.33, 0.12), gold)
			return bud

func _build_player() -> void:
	may = Node3D.new()
	add_child(may)
	character = Node3D.new()
	may.add_child(character)
	if benchmark_mode:
		_sphere(character, Vector3(0, 1.05, 0), Vector3(0.64, 0.80, 0.48), _material(Color("2d5b98")))
		_sphere(character, Vector3(0, 1.62, 0), Vector3.ONE * 0.49, _material(Color("e5b9a6")))
		_cylinder(character, Vector3(0, 1.94, 0), 0.57, 0.03, 0.31, _material(Color("6798c8")), 24)
		for side in [-1, 1]:
			_cylinder(character, Vector3(0.14 * side, 0.45, 0), 0.09, 0.127, 0.67, _material(Color("253450")), 10)
		_add_player_light()
		return
	var shirt := _material(Color("2d5b98"))
	var hem := _material(Color("d7c79c"))
	var trousers := _material(Color("253450"))
	var skin := _material(Color("e5b9a6"))
	var hair := _material(Color("a0c3df"))
	var leather := _material(Color("33364c"))
	var lining := _material(Color("324e78"))
	Costume.tailored(character, [Vector4(0.34,0.65,0.22,0.02), Vector4(0.32,0.74,0.21,0.01),
		Vector4(0.217,1.05,0.16,0), Vector4(0.276,1.26,0.19,-0.012), Vector4(0.23,1.35,0.143,0),
		Vector4(0.10,1.40,0.105,0)], shirt, 0.047)
	Costume.tailored(character, [Vector4(0.345,0.65,0.225,0.02), Vector4(0.34,0.674,0.223,0.019)], hem, 0.047)
	Costume.tailored(character, [Vector4(0.245,0.982,0.183,0), Vector4(0.23,1.04,0.172,0)], lining)
	_sphere(character, Vector3(0, 1.31, 0.015), Vector3(0.73, 0.24, 0.43), shirt)
	_sphere(character, Vector3(0, 1.47, 0), Vector3(0.21, 0.31, 0.22), skin)
	Costume.tailored(character, [Vector4(0.014,1.435,0.04,-0.067), Vector4(0.128,1.49,0.135,-0.054),
		Vector4(0.201,1.57,0.181,-0.048), Vector4(0.224,1.67,0.208,-0.025),
		Vector4(0.22,1.77,0.203,-0.018), Vector4(0.17,1.865,0.154,0), Vector4(0.016,1.91,0.02,0)], skin)
	_sphere(character, Vector3(0, 1.73, 0.10), Vector3(0.49, 0.50, 0.38), hair)
	for i in 7:
		var offset := -0.168 + i * 0.05
		var lock := Costume.tailored(character, [Vector4(0.002,0,0.003,-0.025), Vector4(0.046,0.075,0.036,-0.014),
			Vector4(0.062,0.145,0.048,0), Vector4(0.035,0.21,0.04,0.045)], hair)
		lock.position = Vector3(offset, 1.73 + 0.035 * cos(i * 0.82), -0.204 + absf(offset) * 0.48)
		lock.rotation.z = -0.42
	for side in [-1, 1]:
		var lock := _sphere(character, Vector3(side * 0.215, 1.59, 0.062), Vector3(0.15, 0.42, 0.24), hair)
		lock.rotation.z = side * 0.26
		var tress := Costume.tailored(character, [Vector4(0.008,0,0.008,0.11), Vector4(0.051,0.09,0.05,0.09),
			Vector4(0.069,0.19,0.059,0.035), Vector4(0.052,0.32,0.046,0)], hair)
		tress.position = Vector3(side * 0.17, 1.19, 0.12)
	_sphere(character, Vector3(0, 1.64, -0.235), Vector3(0.051, 0.076, 0.056), skin)
	_sphere(character, Vector3(0, 1.594, -0.233), Vector3(0.064, 0.014, 0.017), _material(Color("b47b78")))
	var collar := _material(Color("809bb1"))
	_branch(character, Vector3(0.14, 1.39, -0.125), Vector3(-0.12, 1.14, -0.18), 0.041, 0.036, collar)
	_branch(character, Vector3(-0.14, 1.39, -0.125), Vector3(0, 1.25, -0.171), 0.041, 0.036, collar)
	var straw := _material(Color("6798c8"))
	var hat := _cylinder(character, Vector3(0, 2.02, 0), 0.51, 0.035, 0.29, straw, 48)
	hat.rotation.z = -0.09
	var brim := Costume.tailored(character, [Vector4(0.512,-0.147,0.512,0), Vector4(0.490,-0.132,0.490,0)], hem)
	brim.transform = hat.transform
	for i in 16:
		var phi := i * TAU / 16
		_branch(hat, Vector3(cos(phi)*0.506,-0.142,sin(phi)*0.506),Vector3(cos(phi)*0.045,0.138,sin(phi)*0.045),0.0035,0.002,hem)
	_inlay(character,Vector3(0,0.815,-0.201),Vector3(0.43,0.47,0.16),PI,hem)
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.14, 0.81, 0)
		character.add_child(leg)
		legs.append(leg)
		_cylinder(leg, Vector3(0, -0.33, 0), 0.09, 0.127, 0.67, trousers, 10)
		Costume.tailored(leg, [Vector4(0.075,-0.72,0.088,0), Vector4(0.085,-0.61,0.081,0),
			Vector4(0.102,-0.45,0.095,0.012), Vector4(0.11,-0.405,0.10,0.012)], leather)
		Costume.tailored(leg, [Vector4(0.109,-0.429,0.103,0.012), Vector4(0.111,-0.409,0.103,0.012)], hem)
		_sphere(leg, Vector3(0, -0.73, -0.075), Vector3(0.24, 0.15, 0.38), leather)
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.34, 1.29, 0)
		character.add_child(arm)
		arms.append(arm)
		_sphere(arm, Vector3(side * 0.035, -0.13, 0), Vector3(0.24, 0.39, 0.23), shirt)
		_cylinder(arm, Vector3(side * 0.052, -0.31, 0), 0.073, 0.077, 0.19, skin, 9)
		_sphere(arm, Vector3(side * 0.06, -0.43, 0), Vector3(0.14, 0.16, 0.15), skin)
		_sphere(character, Vector3(side * 0.22, 1.64, -0.015), Vector3(0.08, 0.15, 0.12), skin)
		var eye := Vector3(side * 0.095, 1.679, -0.226)
		var brow := _sphere(character, eye + Vector3(0, 0.044, 0.015), Vector3(0.084, 0.014, 0.018), _material(Color("647584")))
		brow.rotation.z = side * 0.12
		_sphere(character, eye, Vector3(0.092, 0.044, 0.037), _material(Color("e6ecf2")))
		_sphere(character, eye + Vector3(0, 0, -0.014), Vector3(0.038, 0.042, 0.022), _material(Color("255a94")))
		_sphere(character, eye + Vector3(-0.009, 0.009, -0.026), Vector3.ONE * 0.013, _material(Color("e2f4ff"), 0.4))
	cloak = Node3D.new()
	cloak.position = Vector3(0, 1.36, 0.16)
	character.add_child(cloak)
	var cape := SurfaceTool.new()
	cape.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fabric := _material(Color("396fa8"))
	fabric.cull_mode = BaseMaterial3D.CULL_DISABLED
	for v in [Vector3(-0.27, 0.0, 0), Vector3(0.27, 0.0, 0), Vector3(0.43, -0.62, 0.18),
		Vector3(-0.27, 0.0, 0), Vector3(0.43, -0.62, 0.18), Vector3(-0.06, -0.70, 0.24)]:
		cape.add_vertex(v)
	cape.generate_normals()
	_mesh(cloak, cape.commit(), Vector3.ZERO, fabric)
	_branch(cloak, Vector3(0.43, -0.62, 0.185), Vector3(-0.06, -0.70, 0.246), 0.013, 0.013, hem)
	var clasp := _sphere(cloak, Vector3(0.04, -0.22, 0.11), Vector3(0.19, 0.15, 0.055), hem)
	clasp.rotation.z = -0.45
	_cylinder(character, Vector3(0.43, 1.66, 0), 0.013, 0.013, 0.36, leather, 6)
	_cylinder(character, Vector3(0.43, 1.39, 0), 0.09, 0.09, 0.19, _material(Color("ffd180"), 0.85), 10)
	_add_player_light()

func _add_player_light() -> void:
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.5, 0)
	light.light_color = Color("ffca83")
	light.light_energy = 1.6 if benchmark_mode else 0.52
	light.omni_range = 7
	may.add_child(light)
	# A tiny soft ground marker makes the character readable on a dark island.
	if benchmark_mode:
		_cylinder(may, Vector3(0, 0.018, 0), 0.5, 0.5, 0.015, _material(Color("82704a")), 24)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 62
	camera.far = 240
	add_child(camera)
	camera.make_current()

func _style(background: Color, border: Color = Color("465263")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _label(text: String, font_size: int, color: Color = Color("f5ecd9")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(18, font_size))
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 50
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("252b35"))
	button.add_theme_color_override("font_hover_color", Color("252b35"))
	button.add_theme_stylebox_override("normal", _style(Color("f3c77d"), Color("f3c77d")))
	button.add_theme_stylebox_override("hover", _style(Color("ffdda3"), Color("ffecc9")))
	button.add_theme_stylebox_override("pressed", _style(Color("d5a75f")))
	button.pressed.connect(action)
	return button

func _stat(parent: HBoxContainer, title: String, value: String, width: float) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.add_theme_stylebox_override("panel", _style(Color(0.055, 0.08, 0.13, 0.94)))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_label(title, 12, Color("a4b5bf")))
	var label := _label(value, 23, Color("ffda99"))
	box.add_child(label)
	return label

func _overlay() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.025, 0.04, 0.075, 0.76)
	hud.add_child(overlay)
	return overlay

func _overlay_box(overlay: Control, box_width: float, box_height: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -box_width / 2
	panel.offset_right = box_width / 2
	panel.offset_top = -box_height / 2
	panel.offset_bottom = box_height / 2
	panel.add_theme_stylebox_override("panel", _style(Color("122332"), Color("79715b")))
	overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return box

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28
	top.offset_right = -28
	top.offset_top = 24
	top.add_theme_constant_override("separation", 10)
	hud.add_child(top)
	var brand := VBoxContainer.new()
	brand.add_child(_label("ĐẢO ĐÈN LỒNG", 26))
	night_label = _label("ĐÊM 1   /   ĐẢO BẾN", 13, Color("b4bfcb"))
	brand.add_child(night_label)
	top.add_child(brand)
	hearts_label = _stat(top, "NGỌN LỬA", "● ● ●", 145)
	var left_space := Control.new()
	left_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left_space)
	timer_label = _stat(top, "TRƯỚC BÌNH MINH", "05:00", 175)
	var right_space := Control.new()
	right_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(right_space)
	score_label = _stat(top, "ĐIỂM", "0", 120)
	var mission := VBoxContainer.new()
	mission.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mission.offset_left = -350
	mission.offset_right = -28
	mission.offset_top = 120
	mission.add_theme_constant_override("separation", 9)
	hud.add_child(mission)
	objective_label = _label("THẮP SÁNG HÒN ĐẢO   0 / 5", 17)
	mission.add_child(objective_label)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(260, 5)
	progress_bar.max_value = 5
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override("background", _style(Color("2c3c48")))
	progress_bar.add_theme_stylebox_override("fill", _style(Color("efc77d"), Color("efc77d")))
	mission.add_child(progress_bar)
	minimap = MiniMap.new()
	minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.offset_left = -214
	minimap.offset_top = -239
	minimap.offset_right = -24
	minimap.offset_bottom = -49
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(minimap)
	var map_label := _label("BẢN ĐỒ", 11, Color("b4bfcb"))
	map_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	map_label.position += Vector2(-174, -48)
	hud.add_child(map_label)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_left = 28
	bottom.offset_top = -94
	bottom.offset_right = 870
	bottom.offset_bottom = -24
	bottom.add_theme_stylebox_override("panel", _style(Color(0.055, 0.08, 0.13, 0.94)))
	hud.add_child(bottom)
	var help := VBoxContainer.new()
	bottom.add_child(help)
	hint_label = _label("Đến gần đom đóm để thu thập ánh sáng.", 17, Color("ffda99"))
	help.add_child(hint_label)
	help_keys = _label("", 18, Color("b2c0cc"))
	help.add_child(help_keys)
	carried_label = _label("", 20, Color("ffe095"))
	carried_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(carried_label)
	carried_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	carried_label.offset_left = -200
	carried_label.offset_right = 200
	carried_label.offset_top = -126
	cooldown_label = _label("", 14, Color("ffe095"))
	hud.add_child(cooldown_label)
	cooldown_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	cooldown_label.position += Vector2(-303, -25)
	indicator = _label("", 20, Color("ffd37e"))
	hud.add_child(indicator)
	scent_indicator = _label("", 18, Color("f0b6ff"))
	hud.add_child(scent_indicator)
	fuel_warning = _label("", 18, Color("ffd37e"))
	mission.add_child(fuel_warning)
	feedback_label = _label("", 21, Color("ffdf9d"))
	feedback_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	feedback_label.offset_left = -340
	feedback_label.offset_right = 340
	feedback_label.offset_top = 125
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(feedback_label)
	menu = _overlay()
	var box := _overlay_box(menu, 660, 560)
	box.add_child(_label("Đảo Đèn Lồng", 46))
	box.add_child(_label("ĐÊM 1  —  ĐẢO BẾN", 16, Color("b6c8cb")))
	var story := _label("Cùng Mây gom đom đóm và giữ đèn sáng đến bình minh.", 21)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(story)
	box.add_child(_button("BẮT ĐẦU HÀNH TRÌNH    →", _begin_campaign))
	box.add_child(_button("KHÁM PHÁ RỪNG", _begin_exploration))
	box.add_child(_button("BẢNG XẾP HẠNG", _show_leaderboard))
	box.add_child(_button("CÀI ĐẶT", _open_settings))
	intro_screen = _overlay()
	intro_screen.hide()
	var intro_box := _overlay_box(intro_screen, 600, 290)
	intro_title = _label("", 34)
	intro_box.add_child(intro_title)
	intro_line = _label("", 20)
	intro_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_box.add_child(intro_line)
	intro_box.add_child(_button("BẮT ĐẦU ĐÊM", _start_game))
	end_screen = _overlay()
	end_screen.hide()
	var end_box := _overlay_box(end_screen, 650, 450)
	end_box.add_child(_label("ĐẢO ĐÈN LỒNG  /  KẾT THÚC ĐÊM", 13, Color("e7bc77")))
	end_title = _label("Hòn đảo thức giấc", 35)
	end_box.add_child(end_title)
	end_description = _label("", 21)
	end_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_box.add_child(end_description)
	score_form = HBoxContainer.new()
	end_box.add_child(score_form)
	score_name = LineEdit.new()
	score_name.placeholder_text = "Tên (3–12 ký tự)"
	score_name.max_length = 12
	score_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_name.text_submitted.connect(func(_value: String) -> void: _save_score())
	score_form.add_child(score_name)
	score_button = _button("LƯU ĐIỂM", _save_score)
	score_form.add_child(score_button)
	score_status = _label("", 18)
	end_box.add_child(score_status)
	next_button = _button("ĐÊM KẾ TIẾP    →", _next_night)
	end_box.add_child(next_button)
	retry_button = _button("CHƠI LẠI    /    R", _start_game)
	end_box.add_child(retry_button)
	end_box.add_child(_button("VỀ MÀN HÌNH ĐẦU", _return_menu))
	pause_screen = _overlay()
	pause_screen.hide()
	var pause_box := _overlay_box(pause_screen, 480, 405)
	pause_box.add_child(_label("Nghỉ chân một chút", 32))
	pause_box.add_child(_label("Thời gian trên đảo đang tạm dừng.", 18, Color("b6c8cb")))
	pause_box.add_child(_button("TIẾP TỤC HÀNH TRÌNH", _resume))
	pause_box.add_child(_button("CHƠI LẠI ĐÊM", _start_game))
	pause_box.add_child(_button("CÀI ĐẶT", _open_settings))
	pause_box.add_child(_button("VỀ MENU", _return_menu))
	settings_screen = _overlay()
	settings_screen.hide()
	var settings_box := _overlay_box(settings_screen, 540, 510)
	settings_box.add_child(_label("Cài đặt", 32))
	_add_slider(settings_box, "Âm lượng", 0, 1, volume, _set_volume)
	_add_slider(settings_box, "Độ nhạy chuột", 0.25, 2.5, mouse_sensitivity, _set_sensitivity)
	var palette := CheckButton.new()
	palette.text = "Bảng màu dễ phân biệt"
	palette.button_pressed = accessible_palette
	palette.toggled.connect(_set_accessible_palette)
	settings_box.add_child(palette)
	_add_toggle(settings_box, "Giảm chuyển động", reduced_motion, _set_reduced_motion)
	_add_toggle(settings_box, "Chữ lớn ×1.25", large_text, _set_large_text)
	settings_box.add_child(_button("ĐỔI PHÍM", func() -> void: keys_screen.show()))
	settings_box.add_child(_button("QUAY LẠI", settings_screen.hide))
	keys_screen = _overlay()
	keys_screen.hide()
	var keys_box := _overlay_box(keys_screen, 690, 550)
	keys_box.add_child(_label("Đổi phím điều khiển", 30))
	keys_status = _label("Chọn hành động rồi bấm phím mới.", 18)
	keys_box.add_child(keys_status)
	var key_grid := GridContainer.new()
	key_grid.columns = 2
	key_grid.add_theme_constant_override("h_separation", 12)
	keys_box.add_child(key_grid)
	for action in ACTION_KEYS:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 40
		button.pressed.connect(_request_key.bind(action))
		key_buttons[action] = button
		key_grid.add_child(_label(ACTION_LABELS[action], 18))
		key_grid.add_child(button)
	keys_box.add_child(_button("KHÔI PHỤC MẶC ĐỊNH", _reset_keys))
	keys_box.add_child(_button("QUAY LẠI", _close_keys))
	_refresh_key_labels()
	leaderboard_screen = _overlay()
	leaderboard_screen.hide()
	var board_box := _overlay_box(leaderboard_screen, 570, 550)
	board_box.add_child(_label("Bảng xếp hạng", 36))
	leaderboard_rows = _label("", 21)
	board_box.add_child(leaderboard_rows)
	board_box.add_child(_button("VỀ MENU", leaderboard_screen.hide))

func _add_toggle(parent: VBoxContainer, title: String, enabled: bool, callback: Callable) -> void:
	var button := CheckButton.new()
	button.text = title
	button.button_pressed = enabled
	button.toggled.connect(callback)
	parent.add_child(button)

func _request_key(action: String) -> void:
	rebind_action = action
	keys_status.text = "Bấm phím mới cho " + ACTION_LABELS[action]

func _close_keys() -> void:
	rebind_action = ""
	keys_screen.hide()

func _reset_keys() -> void:
	rebind_action = ""
	key_bindings = ACTION_KEYS.duplicate()
	keys_status.text = "Đã khôi phục phím mặc định."
	_save_bindings()

func _refresh_key_labels() -> void:
	for action in key_buttons:
		key_buttons[action].text = OS.get_keycode_string(key_bindings[action])
	help_keys.text = "%s %s %s %s · Đi    %s · Nhảy    %s · Lướt    %s · Đèn    %s · Tỏa    %s · Dừng" % [
		_key("forward"), _key("left"), _key("backward"), _key("right"), _key("jump"), _key("dash"), _key("interact"), _key("pulse"), _key("pause")]

func _key(action: String) -> String:
	return OS.get_keycode_string(key_bindings[action])

func _show_leaderboard() -> void:
	var entries: Array = leaderboard.entries()
	var lines := PackedStringArray()
	for i in entries.size():
		lines.append("%02d    %s    ·    %d điểm    ·    %d/3 Đêm" % [i + 1, entries[i].name, entries[i].score, entries[i].nights_won])
	leaderboard_rows.text = "\n".join(lines) if not lines.is_empty() else "Chưa có điểm được lưu."
	leaderboard_screen.show()

func _save_score() -> void:
	if not score_form.visible or score_button.disabled:
		return
	var name_value := score_name.text
	if not Leaderboard.valid_name(name_value):
		score_status.text = "Tên cần 3–12 chữ cái, số hoặc dấu gạch dưới."
		return
	var nights_won := campaign_night if sim.state == "won" else campaign_night - 1
	var error: Error = leaderboard.record(name_value, campaign_score, nights_won, start_seed)
	score_status.text = "Đã lưu điểm." if error == OK else "Không lưu được điểm."
	score_button.disabled = error == OK

func _load_settings() -> void:
	settings.load(settings_path)
	volume = clampf(float(settings.get_value("game", "volume", 0.75)), 0, 1)
	mouse_sensitivity = clampf(float(settings.get_value("game", "sensitivity", 1.0)), 0.25, 2.5)
	accessible_palette = bool(settings.get_value("game", "accessible_palette", false))
	reduced_motion = bool(settings.get_value("game", "reduced_motion", false))
	large_text = bool(settings.get_value("game", "large_text", false))
	var saved: Variant = settings.get_value("game", "keys", {})
	if saved is Dictionary:
		for action in ACTION_KEYS:
			var value: Variant = saved.get(action)
			if value is int and value > 0:
				key_bindings[action] = value
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	AudioServer.set_bus_mute(0, volume == 0)

func _add_slider(parent: VBoxContainer, title: String, low: float, high: float, value: float, callback: Callable) -> void:
	parent.add_child(_label(title, 16))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01
	slider.value = value
	parent.add_child(slider)
	slider.value_changed.connect(callback)

func _set_volume(value: float) -> void:
	volume = value
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.001)))
	AudioServer.set_bus_mute(0, value == 0)
	settings.set_value("game", "volume", value)
	_save_settings()

func _set_sensitivity(value: float) -> void:
	mouse_sensitivity = value
	settings.set_value("game", "sensitivity", value)
	_save_settings()

func _set_accessible_palette(value: bool) -> void:
	accessible_palette = value
	settings.set_value("game", "accessible_palette", value)
	_save_settings()

func _set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	settings.set_value("game", "reduced_motion", value)
	_save_settings()

func _set_large_text(value: bool) -> void:
	large_text = value
	settings.set_value("game", "large_text", value)
	_save_settings()
	_apply_text_size()

func _apply_text_size() -> void:
	for node in hud.find_children("*", "Control", true, false):
		if node is Label or node is BaseButton or node is LineEdit:
			if not node.has_meta("base_font_size"):
				node.set_meta("base_font_size", maxi(18, node.get_theme_font_size("font_size")))
			node.add_theme_font_size_override("font_size", roundi(float(node.get_meta("base_font_size")) * (1.25 if large_text else 1.0)))

func _save_settings() -> void:
	var error := settings.save(settings_path)
	if error != OK:
		push_warning("Không lưu được cài đặt: " + error_string(error))

func _warning_color() -> Color:
	return Color("FFFFFF") if accessible_palette else Color("FF5A5F")

func _open_settings() -> void:
	settings_screen.show()

func _begin_campaign() -> void:
	exploring = false
	campaign_night = 1
	campaign_score = 0
	_show_intro()

func _begin_exploration() -> void:
	exploring = true
	exploration_seed = randi()
	campaign_night = 1
	campaign_score = 0
	start_scenario = {}
	_start_game()
	_toast("Khám phá rừng · Đèn đổi chỗ mỗi chuyến")

func _next_night() -> void:
	if campaign_night < 3:
		campaign_night += 1
		start_scenario = {}
		_show_intro()

func _show_intro() -> void:
	active = false
	menu.hide()
	end_screen.hide()
	intro_title.text = "Đêm %d · %s" % [campaign_night, Layout.NAMES[campaign_night - 1]]
	var lines := [
		"Giữ ít nhất 3 đèn sáng đến bình minh. Châm thêm dầu khi đèn yếu.",
		"Cầu tre nối hai đảo. Giữ ít nhất 4 đèn sáng đến bình minh.",
		"Theo dốc và bục gió lên tháp chuông. Giữ ít nhất 5 đèn sáng đến bình minh."
	]
	intro_line.text = "Ông Đăng\n“%s”" % lines[campaign_night - 1]
	intro_screen.show()

func _start_game() -> void:
	var previous_night: int = sim.night
	var previous_exploration: bool = sim.exploration
	sim = Simulation.new(exploration_seed if exploring else start_seed, start_scenario, campaign_night, exploring)
	if previous_night != campaign_night or previous_exploration or exploring:
		_build_island()
	active = true
	paused = false
	yaw = 0
	pitch = 0.42
	menu.hide()
	intro_screen.hide()
	settings_screen.hide()
	end_screen.hide()
	pause_screen.hide()
	pulse_age = 5
	toast_time = 0
	feedback_priority = 0
	latest_shade_id = ""
	spawn_notice_until = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture_path.is_empty() else Input.MOUSE_MODE_VISIBLE
	_sync_visuals(0)
	_update_camera(true)

func _return_menu() -> void:
	active = false
	paused = false
	end_screen.hide()
	intro_screen.hide()
	pause_screen.hide()
	settings_screen.hide()
	_close_keys()
	leaderboard_screen.hide()
	menu.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume() -> void:
	paused = false
	pause_screen.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and active and sim.state == "lost":
		_start_game()
	if event.is_action_pressed("pause") and active and sim.state == "playing":
		if keys_screen.visible:
			_close_keys()
		elif settings_screen.visible:
			settings_screen.hide()
		elif paused:
			_resume()
		else:
			paused = true
			pause_screen.show()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and active and not paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.003 * mouse_sensitivity
		pitch = clampf(pitch + event.relative.y * 0.002 * mouse_sensitivity, 0.15, 0.95)

func _physics_process(_delta: float) -> void:
	if benchmark_mode:
		sim.benchmark_step()
		return
	if not active or paused or sim.state != "playing":
		return
	var movement := Input.get_vector("left", "right", "forward", "backward")
	var was_grounded: bool = sim.grounded
	var previous_seconds := int(ceil(sim.time_left_s))
	sim.step({"move": [movement.x, movement.y], "cam_yaw_deg": rad_to_deg(yaw),
		"jump": Input.is_action_pressed("jump"), "interact": Input.is_action_pressed("interact"),
		"pulse": Input.is_action_pressed("pulse"), "dash": Input.is_action_pressed("dash")})
	if was_grounded and not sim.grounded and sim.velocity.y > 0:
		sound.cue("jump")
	var seconds := int(ceil(sim.time_left_s))
	if seconds < previous_seconds and seconds > 0 and seconds <= 10:
		sound.cue("countdown")
		_toast("Bình minh sau %d giây" % seconds, true, 3)
	if sim.night == 3 and sim.wind_enabled and sim.sim_tick % 1800 == 1680:
		sound.cue("wind_warning")
		_toast("Gió mạnh sắp thổi", true, 2)
	var played: Dictionary = {}
	for event in sim.events:
		if not played.has(event.name):
			sound.cue(event.name)
			played[event.name] = true
		match event.name:
			"lantern_lit":
				_toast("Đèn đã được thắp lại  +40" if event.data.relight else "Một ngọn đèn đã sáng  +100")
			"lantern_out":
				_toast("%s đã cạn dầu" % event.data.lantern_id, true)
			"shade_spawned":
				latest_shade_id = event.data.id
				spawn_notice_until = sim.sim_tick + 180
				_toast("Bóng Mực xuất hiện", true)
			"pulse":
				pulse_age = 0
				pulse_ring.position = Vector3(sim.player.pos.x, 0.15, sim.player.pos.z)
			"player_hit":
				_toast("Rơi xuống biển mây  −1 ngọn lửa" if event.data.by == "fall" else "Bóng Mực chạm vào Mây  −1 ngọn lửa", true)
			"game_over":
				_show_end(event.data.reason)

func _toast(message: String, warning: bool = false, priority: int = 1) -> void:
	if toast_time > 0 and priority < feedback_priority:
		return
	feedback_priority = priority
	feedback_label.text = ("⚠ " if warning and accessible_palette else "") + message
	feedback_label.add_theme_color_override("font_color", _warning_color() if warning else Color("ffdf9d"))
	toast_time = 2.5

func _show_end(reason: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var won: bool = sim.state == "won"
	sound.cue(sim.state)
	if won:
		campaign_score += sim.score
	next_button.visible = won and campaign_night < 3 and not exploring
	end_title.text = "Hòn đảo đã sáng trở lại!" if sim.state == "won" else "Đốm sáng sẽ lại trở về"
	if won and campaign_night == 3:
		end_title.text = "Bình Minh"
	var explanation := "Mây đã giữ đủ đèn sáng tới bình minh." if won else ("Bình minh đến khi số đèn sáng còn dưới mức cần thiết." if reason == "dawn" else "Mây đã hết ngọn lửa. Hãy thử lại nhé.")
	end_description.text = "%s\n\nĐiểm đêm: %d  ·  Đèn: %d/%d\nTổng điểm: %d" % [explanation, sim.score, _count_lit(), sim.lanterns.size(), campaign_score]
	retry_button.visible = not won
	score_form.visible = not exploring and (not won or campaign_night == 3)
	score_name.clear()
	score_status.text = ""
	score_button.disabled = false
	end_screen.show()

func _count_lit() -> int:
	var total := 0
	for lantern in sim.lanterns:
		if lantern.lit:
			total += 1
	return total

func _process(delta: float) -> void:
	visual_time += delta
	if not paused:
		_sync_visuals(delta)
		if not benchmark_mode:
			_update_camera(false)
	toast_time = maxf(0, toast_time - delta)
	feedback_label.visible = toast_time > 0
	if not capture_path.is_empty():
		capture_frame += 1
		if capture_frame == 45:
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var error := image.save_png(capture_path)
			if error != OK:
				push_error("Could not save screenshot: " + capture_path)
			get_tree().quit(0 if error == OK else 1)

func _sync_visuals(delta: float) -> void:
	may.position = sim.player.pos
	var walk := Input.get_vector("left", "right", "forward", "backward") if active and not paused else Vector2.ZERO
	if walk.length_squared() > 0.01:
		var angle := atan2(-walk.x, -walk.y) + yaw
		character.rotation.y = lerp_angle(character.rotation.y, angle, 0.18)
		character.position.y = sin(visual_time * 17) * 0.045
	else:
		character.position.y = sin(visual_time * 3) * 0.025
	var stride := sin(visual_time * 12.5) * 0.57 if walk.length_squared() > 0.01 else 0.0
	if cloak != null:
		cloak.rotation.x = 0.03 if reduced_motion else sin(visual_time * 2.5) * 0.05 + absf(stride) * 0.26
	for i in legs.size():
		var swing := stride if i == 0 else -stride
		legs[i].rotation.x = lerpf(legs[i].rotation.x, swing if sim.grounded else -0.23, 0.18)
		arms[i].rotation.x = lerpf(arms[i].rotation.x, -swing * 0.62 if sim.grounded else 0.34, 0.18)
	character.visible = sim.sim_tick >= sim.invuln_until or sim.sim_tick % 10 < 6
	var alive_motes: Dictionary = {}
	for mote in sim.motes:
		alive_motes[mote.id] = true
		if not mote_nodes.has(mote.id):
			var mote_root := Node3D.new()
			add_child(mote_root)
			var core := _sphere(mote_root, Vector3.ZERO, Vector3.ONE * 0.14, mote_material)
			core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_mesh(mote_root, mote_halo_mesh, Vector3.ZERO, mote_halo_material).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mote_nodes[mote.id] = mote_root
		var node: Node3D = mote_nodes[mote.id]
		var phase := visual_time * 1.65 + float(str(mote.id).substr(1)) * 1.638
		var flight := 0.0 if reduced_motion or benchmark_mode else 1.0
		node.position = mote.pos + Vector3(cos(phase) * 0.72 * flight,
			0.82 + (0.5 + 0.5 * sin(phase * 0.72)) * 0.95 * flight, sin(phase * 1.12) * 0.58 * flight)
	for id in mote_nodes.keys():
		if not alive_motes.has(id):
			mote_nodes[id].queue_free()
			mote_nodes.erase(id)
	if benchmark_mode:
		_sync_shade_batches()
	else:
		_sync_shade_nodes()
	lit_count = _count_lit()
	_sync_lanterns_and_hud(delta)

func _sync_shade_nodes() -> void:
	var alive_shades: Dictionary = {}
	for shade in sim.shades:
		alive_shades[shade.id] = true
		if not shade_nodes.has(shade.id):
			var root := Node3D.new()
			add_child(root)
			var body := _sphere(root, Vector3(0, 0.8, 0), Vector3(1.1, 1.45, 0.9), _material(Color("44315b")))
			_cylinder(root, Vector3(0, 0.3, 0), 0.65, 0.4, 0.5, _material(Color("44315b")), 7)
			var accent := _material(Color("7A3CFF"), 0.8)
			var trim := TorusMesh.new()
			trim.inner_radius = 0.42
			trim.outer_radius = 0.48
			var edge := _mesh(root, trim, Vector3(0, 0.38, 0), accent)
			edge.scale.y = 0.48
			for side in [-1, 1]:
				_sphere(root, Vector3(side * 0.2, 1.0, -0.4), Vector3(0.12, 0.16, 0.09), accent)
			shade_nodes[shade.id] = {"root": root, "body": body, "accent": accent}
		var nodes: Dictionary = shade_nodes[shade.id]
		nodes.root.position = shade.pos + Vector3(0, sin(visual_time * 3) * 0.12, 0)
		var look_target: Vector3 = sim.player.pos
		if shade.state == "drain" and lantern_nodes.has(shade.target_lantern_id):
			look_target = lantern_nodes[shade.target_lantern_id].root.position
		var direction: Vector3 = look_target - shade.pos
		if Vector2(direction.x, direction.z).length_squared() > 0.01:
			nodes.root.rotation.y = atan2(-direction.x, -direction.z)
		var accent_color := Color("00B3FF") if accessible_palette else Color("7A3CFF")
		nodes.accent.albedo_color = accent_color
		nodes.accent.emission = accent_color
		nodes.body.material_override.albedo_color = Color("a697c5") if shade.state == "stunned" else Color("44315b")
	for id in shade_nodes.keys():
		if not alive_shades.has(id):
			shade_nodes[id].root.queue_free()
			shade_nodes.erase(id)

func _add_shade_batch(mesh: Mesh, material: Material, count: int) -> void:
	mesh.surface_set_material(0, material)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = count
	shade_batches.append(batch)
	var node := MultiMeshInstance3D.new()
	node.multimesh = batch
	add_child(node)

func _sync_shade_batches() -> void:
	if shade_batches.is_empty():
		var body := SphereMesh.new()
		body.radial_segments = 12
		body.rings = 6
		_add_shade_batch(body, _material(Color("44315b")), sim.shades.size())
		var skirt := CylinderMesh.new()
		skirt.top_radius = 0.4
		skirt.bottom_radius = 0.65
		skirt.height = 0.5
		skirt.radial_segments = 7
		_add_shade_batch(skirt, _material(Color("44315b")), sim.shades.size())
		var trim := TorusMesh.new()
		trim.inner_radius = 0.42
		trim.outer_radius = 0.48
		trim.rings = 24
		trim.ring_segments = 12
		var accent := _material(Color("7A3CFF"), 0.8)
		_add_shade_batch(trim, accent, sim.shades.size())
		var eye := SphereMesh.new()
		eye.radial_segments = 10
		eye.rings = 5
		_add_shade_batch(eye, accent, sim.shades.size() * 2)
	for i in sim.shades.size():
		var shade: Dictionary = sim.shades[i]
		var pos: Vector3 = shade.pos + Vector3(0, sin(visual_time * 3) * 0.12, 0)
		var orientation := Basis(Vector3.UP, atan2(shade.pos.x, shade.pos.z))
		shade_batches[0].set_instance_transform(i, Transform3D(orientation.scaled(Vector3(1.1, 1.45, 0.9)), pos + Vector3.UP * 0.8))
		shade_batches[1].set_instance_transform(i, Transform3D(orientation, pos + Vector3.UP * 0.3))
		shade_batches[2].set_instance_transform(i, Transform3D(orientation.scaled(Vector3(1, 0.48, 1)), pos + Vector3.UP * 0.38))
		for eye in 2:
			var offset := orientation * Vector3(-0.2 + eye * 0.4, 1.0, -0.4)
			shade_batches[3].set_instance_transform(i * 2 + eye, Transform3D(orientation.scaled(Vector3(0.12, 0.16, 0.09)), pos + offset))

func _sync_lanterns_and_hud(delta: float) -> void:
	var low_lamps := PackedStringArray()
	for lantern in sim.lanterns:
		var nodes: Dictionary = lantern_nodes[lantern.id]
		nodes.root.position = lantern.pos
		var fuel_value: float = lantern.fuel_units / 60.0
		var weak: bool = lantern.lit and not sim.has_safety(lantern)
		if weak:
			low_lamps.append(lantern.id)
		var flicker := 0.55 + 0.45 * (0.5 + 0.5 * cos(visual_time * TAU)) if weak and not reduced_motion else 1.0
		nodes.shell.scale.y = 1.0 if lantern.lit else 0.8
		nodes.tear.visible = not lantern.lit
		var glow: Color = [Color("ff7851"), Color("ffc978"), Color("e9edaa")][nodes.style]
		if benchmark_mode:
			nodes.body.material_override.albedo_color = glow if lantern.lit else Color("736761")
			nodes.body.material_override.emission = glow if lantern.lit else Color("736761")
			nodes.body.material_override.emission_energy_multiplier = 1.4 * flicker if lantern.lit else 0.15
		else:
			nodes.body.material_override.set_shader_parameter("paper_tint", glow)
			nodes.body.material_override.set_shader_parameter("flame", flicker if lantern.lit else 0.0)
		nodes.light.light_energy = (2.85 if benchmark_mode else 1.48) * flicker if lantern.lit else 0.1
		nodes.halo.visible = lantern.lit
		nodes.ring.visible = sim.has_safety(lantern)
		nodes.bar.visible = lantern.lit
		nodes.bar_material.set_shader_parameter("fill", fuel_value / float(sim.tuning.fuel_max))
		nodes.bar_material.set_shader_parameter("fill_color", _warning_color() if weak else Color("ffc978"))
		nodes.bar_material.set_shader_parameter("intensity", flicker)
		nodes.marker.text = lantern.id + (" · %s%d" % ["⚠ " if weak and accessible_palette else "", floori(fuel_value)]
			if lantern.lit else " · %d/%d" % [lantern.deposited, sim.light_cost(lantern)])
	var progress: float = float(lit_count) / sim.lanterns.size()
	world_environment.environment.ambient_light_energy = 0.15 + 0.55 * progress
	world_environment.environment.fog_density = 0.006 - lit_count * 0.0007
	sky_material.set_shader_parameter("lantern_light", progress)
	pulse_age += delta
	pulse_ring.visible = pulse_age < 0.5 and not reduced_motion
	if pulse_ring.visible:
		var scale_value := maxf(0.1, pulse_age / 0.5 * float(sim.tuning.pulse_radius))
		pulse_ring.scale = Vector3(scale_value, 0.05, scale_value)
	hearts_label.text = "● ".repeat(maxi(0, int(sim.player.flames))).strip_edges()
	night_label.text = "KHÁM PHÁ RỪNG" if exploring else "ĐÊM %d   /   %s" % [sim.night, Layout.NAMES[sim.night - 1].to_upper()]
	carried_label.text = "ĐOM ĐÓM    %d / %d" % [sim.player.carried, sim.capacity()]
	var seconds := maxi(0, int(ceil(sim.time_left_s)))
	timer_label.text = "%s%02d:%02d" % ["⚠ " if seconds <= 30 and accessible_palette else "", seconds / 60, seconds % 60]
	timer_label.add_theme_color_override("font_color", _warning_color() if seconds <= 30 else Color("ffda99"))
	timer_label.modulate.a = 0.55 + 0.45 * absf(sin(visual_time * 4)) if seconds <= 30 and not reduced_motion else 1.0
	fuel_warning.text = ("⚠ " if accessible_palette else "") + "Đèn yếu " + ", ".join(low_lamps) if not low_lamps.is_empty() else ""
	fuel_warning.add_theme_color_override("font_color", _warning_color())
	score_label.text = str(sim.score)
	objective_label.text = "ĐÈN SÁNG  %d/%d  ·  CẦN %d" % [lit_count, sim.lanterns.size(), sim.required_lights()]
	progress_bar.max_value = sim.lanterns.size()
	progress_bar.value = lit_count
	var near: Dictionary = sim.nearest_lantern()
	var cooldown := maxf(0, (sim.pulse_ready_tick - sim.sim_tick) / 60.0)
	var dash_cd := maxf(0, (sim.dash_ready_tick - sim.sim_tick) / 60.0) if sim.charm_until <= sim.sim_tick else 0.0
	cooldown_label.text = "%s Lướt %s    %s Tỏa %s" % [_key("dash"), "%.1fs" % dash_cd if dash_cd > 0 else "✓", _key("pulse"), "%.1fs" % cooldown if cooldown > 0 else "✓"]
	if not near.is_empty():
		hint_label.text = "%s — Châm dầu (%d/100) · %s" % [_key("interact"), floori(near.fuel_units / 60.0), near.id] if near.lit else "%s — Nạp ánh sáng (%d/%d) · %s" % [_key("interact"), near.deposited, sim.light_cost(near), near.id]
	elif cooldown > 0:
		hint_label.text = "Tỏa sáng đang hồi: %.1f giây  ·  Tìm vùng đèn sáng để trú ẩn." % cooldown
	elif sim.player.carried >= sim.capacity():
		hint_label.text = "Túi đã đầy! Mang đom đóm về thắp đèn hoặc châm dầu."
	else:
		hint_label.text = "Gom đom đóm hoặc tìm đèn để châm dầu."
	minimap.simulation = sim
	minimap.queue_redraw()
	_sync_special()
	_update_indicator()
	scent_indicator.hide()
	if active and sim.sim_tick < spawn_notice_until and shade_nodes.has(latest_shade_id):
		_place_edge_indicator(scent_indicator, shade_nodes[latest_shade_id].root.position, "Bóng Mực", true)

func _sync_special() -> void:
	var live: Dictionary = {}
	for charm in sim.charms:
		live[charm.id] = true
		if not special_nodes.has(charm.id):
			var root := Node3D.new()
			map_root.add_child(root)
			_box(root, Vector3.ZERO, Vector3(0.55, 0.76, 0.12), _material(Color("ffd266"), 0.45))
			_box(root, Vector3.ZERO, Vector3(0.43, 0.62, 0.14), _material(Color("b73749"), 0.35))
			special_nodes[charm.id] = root
		var charm_node: Node3D = special_nodes[charm.id]
		charm_node.position = charm.pos + Vector3.UP * (0.9 + sin(visual_time * 3) * 0.18)
		charm_node.rotation.y = visual_time
		charm_node.visible = charm.ready <= sim.sim_tick
	for drifter in sim.drifters:
		live[drifter.id] = true
		if not special_nodes.has(drifter.id):
			var root := Node3D.new()
			map_root.add_child(root)
			var silk := _material(Color("76a4ad"), 0.26)
			for i in 5:
				_sphere(root, Vector3.ZERO, Vector3(0.38, 0.10, 0.51), silk)
			special_nodes[drifter.id] = root
		var drifter_node: Node3D = special_nodes[drifter.id]
		drifter_node.position = drifter.pos + Vector3.UP * 1.25
		drifter_node.rotation.y = atan2(drifter.direction.x, drifter.direction.z)
		for i in drifter_node.get_child_count():
			drifter_node.get_child(i).position = Vector3(sin(visual_time * 8 - i) * 0.3, cos(visual_time * 7 - i) * 0.18, i * 0.3)
	for id in special_nodes.keys():
		if not live.has(id):
			special_nodes[id].queue_free()
			special_nodes.erase(id)
	for i in wind_leaves.size():
		var leaf := wind_leaves[i]
		leaf.visible = sim.wind_enabled and (sim.wind_active or sim.sim_tick % 1800 >= 1680)
		if leaf.visible:
			var phase := fposmod(visual_time * 6 + i * 3.1, 24.0) - 12.0
			var angle: float = sim.wind_dir if sim.wind_active else 25.0
			leaf.position = sim.player.pos + Layout.radial(phase, angle) + Layout.radial(i % 7 - 3, angle + 90) + Vector3.UP * (1 + i % 5 * 0.4)
			leaf.rotation = Vector3(visual_time * 4 + i, deg_to_rad(angle), visual_time * 2)

func _update_indicator() -> void:
	indicator.hide()
	if not active or paused or sim.state != "playing":
		return
	var nearest: Dictionary = {}
	var best := INF
	for lantern in sim.lanterns:
		var distance := Simulation.horizontal(sim.player.pos, lantern.pos)
		if not lantern.lit and distance < best:
			best = distance
			nearest = lantern
	if nearest.is_empty():
		return
	_place_edge_indicator(indicator, nearest.pos + Vector3.UP * 3, nearest.id)

func _place_edge_indicator(label: Label, target: Vector3, title: String, always: bool = false) -> void:
	var bounds := get_viewport().get_visible_rect().grow(-65)
	var screen := camera.unproject_position(target)
	var behind := camera.is_position_behind(target)
	if not always and not behind and bounds.has_point(screen):
		return
	var center := bounds.get_center()
	var offset := screen - center
	if behind:
		offset = -offset
	if offset.length_squared() < 1:
		offset = Vector2.DOWN
	var edge := center + offset / maxf(absf(offset.x) / (bounds.size.x / 2), absf(offset.y) / (bounds.size.y / 2))
	var arrows := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	label.text = "%s %s" % [arrows[posmod(roundi(offset.angle() / (PI / 4)), 8)], title]
	var text_size := label.get_minimum_size()
	label.position = Vector2(clampf(edge.x - text_size.x / 2, 12, get_viewport().get_visible_rect().size.x - text_size.x - 12),
		edge.y - 12)
	label.show()

func _update_camera(instant: bool) -> void:
	var target: Vector3 = sim.player.pos + Vector3(0, 1.1, 0)
	var distance := 10.5
	var position_target := target + Vector3(sin(yaw) * cos(pitch) * distance, sin(pitch) * distance + 1.8, cos(yaw) * cos(pitch) * distance)
	if sim.night == 3 and target.y < 5.1 and Vector2(target.x, target.z).length() <= 8.5:
		position_target.y = minf(position_target.y, 4.95)
	camera.position = position_target if instant else camera.position.lerp(position_target, 0.15)
	camera.look_at(target)

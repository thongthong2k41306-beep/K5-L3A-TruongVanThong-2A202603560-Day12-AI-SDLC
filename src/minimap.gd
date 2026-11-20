extends Control
var simulation: RefCounted

func _draw() -> void:
	if simulation == null:
		return
	var center := size / 2
	var radius := minf(size.x, size.y) * 0.44
	var map_offset := Vector2(35, 0) if simulation.night == 2 else Vector2.ZERO
	var map_scale: float = radius / (63.0 if simulation.night == 2 else simulation.island_radius)
	draw_circle(center, radius + 8, Color("111e30"))
	draw_arc(center, radius + 8, 0, TAU, 80, Color("586578"), 1.0, true)
	if simulation.night == 2:
		draw_rect(Rect2(center + Vector2(-9, -2) * map_scale, Vector2(18, 4) * map_scale), Color("987a4d"))
		for x in [-35, 35]:
			draw_circle(center + Vector2(x, 0) * map_scale, 28 * map_scale, Color("234b49"))
	else:
		draw_circle(center, radius, Color("234b49"))
	for lantern in simulation.lanterns:
		var point := center + (Vector2(lantern.pos.x, lantern.pos.z) - map_offset) * map_scale
		if lantern.lit:
			draw_circle(point, 10, Color(1, 0.7, 0.25, 0.15))
		draw_circle(point, 4.5, Color("ffce80") if lantern.lit else Color("8c8b9f"))
	for shade in simulation.shades:
		draw_circle(center + (Vector2(shade.pos.x, shade.pos.z) - map_offset) * map_scale, 2.5, Color("c17ee8"))
	var player_point := center + (Vector2(simulation.player.pos.x, simulation.player.pos.z) - map_offset) * map_scale
	draw_circle(player_point, 5, Color("fff1ce"))
	draw_arc(player_point, 8, 0, TAU, 24, Color("f8bd62"), 1.0, true)

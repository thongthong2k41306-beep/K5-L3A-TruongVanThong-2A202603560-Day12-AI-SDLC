shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(1.0, 0.75, 0.30, 1.0);
uniform float intensity = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]
	);
}

void fragment() {
	vec3 track = vec3(0.035, 0.06, 0.085);
	bool edge = UV.x < 0.025 || UV.x > 0.975 || UV.y < 0.12 || UV.y > 0.88;
	ALBEDO = edge ? vec3(0.32, 0.40, 0.43) : (UV.x < fill ? fill_color.rgb * intensity : track);
}

shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.60, 0.19, 0.48);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]
	);
}

void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	float falloff = max(0.0, 1.0 - radius);
	ALBEDO = glow_color.rgb;
	ALPHA = falloff * falloff * glow_color.a;
}

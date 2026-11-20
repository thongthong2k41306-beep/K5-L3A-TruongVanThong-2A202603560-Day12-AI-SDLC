shader_type spatial;
render_mode diffuse_burley;

uniform vec4 paper_tint : source_color;
uniform float flame = 0.0;
varying vec3 shell;

void vertex() {
	shell = VERTEX;
}

void fragment() {
	float h = clamp(UV.y, 0.0, 1.0);
	float distance_to_flame = dot(shell.xz, shell.xz) * 0.24 + pow((h - 0.54) * 1.75, 2.0);
	float light_inside = exp(-2.7 * distance_to_flame);
	float fibers = sin((UV.x + 0.001 * sin(UV.y * 74.0)) * 780.0) * sin(UV.y * 417.0);
	float ribs = 1.0 - 0.16 * pow(abs(cos(h * PI * 6.0)), 16.0);
	vec3 parchment = mix(vec3(0.33, 0.27, 0.22), paper_tint.rgb, 0.32 + 0.68 * flame);
	ALBEDO = parchment * ribs * (0.77 + fibers * 0.045);
	EMISSION = mix(parchment, vec3(1.0, 0.77, 0.44), light_inside * 0.48) * light_inside * flame * ribs;
	ROUGHNESS = 0.92;
}

shader_type spatial;
render_mode diffuse_burley;

varying vec2 ground_position;
uniform bool painted = false;
uniform sampler2D meadow : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

float hash_cell(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float noise_at(vec2 point) {
	vec2 cell = floor(point);
	vec2 t = fract(point);
	t = t * t * (3.0 - 2.0 * t);
	return mix(
		mix(hash_cell(cell), hash_cell(cell + vec2(1.0, 0.0)), t.x),
		mix(hash_cell(cell + vec2(0.0, 1.0)), hash_cell(cell + vec2(1.0, 1.0)), t.x),
		t.y
	);
}

void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float moss = noise_at(ground_position * 0.24) * 0.75 + noise_at(ground_position * 0.9) * 0.25;
	float grain = noise_at(ground_position * 7.0);
	vec3 grass = mix(vec3(0.030, 0.065, 0.073), vec3(0.083, 0.175, 0.141), moss);
	float rim = smoothstep(29.0, 35.0, length(ground_position));
	ALBEDO = mix(grass, vec3(0.087, 0.096, 0.105), rim * 0.65) * mix(0.87, 1.12, grain);
	if (painted) {
		vec2 uv = ground_position * 0.48;
		vec3 first = texture(meadow, uv).rgb;
		vec3 second = texture(meadow, mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.74).rgb;
		vec3 leaf_litter = mix(first, second, smoothstep(0.32, 0.72, moss));
		leaf_litter = mix(vec3(dot(leaf_litter, vec3(0.25,0.62,0.13))), leaf_litter, 0.72);
		ALBEDO = leaf_litter * mix(vec3(0.48, 0.59, 0.55), vec3(0.76, 0.83, 0.74), moss);
	}
	ROUGHNESS = 0.92;
}

shader_type sky;

uniform float lantern_light : hint_range(0.0, 1.0) = 0.0;
uniform bool painted = false;
uniform sampler2D mountains : source_color, filter_linear_mipmap, repeat_enable;

float hash_cell(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
	float elevation = EYEDIR.y;
	vec3 horizon = mix(vec3(0.095, 0.13, 0.24), vec3(0.20, 0.18, 0.29), lantern_light);
	vec3 sky_color = mix(horizon, vec3(0.012, 0.018, 0.064), smoothstep(-0.04, 0.65, elevation));
	sky_color = mix(sky_color, vec3(0.041, 0.057, 0.13), smoothstep(0.02, 0.28, -elevation));

	vec2 stars = SKY_COORDS * vec2(190.0, 95.0);
	vec2 cell = floor(stars);
	float seed = hash_cell(cell);
	vec2 offset = vec2(hash_cell(cell + 7.0), hash_cell(cell + 21.0));
	float star = 1.0 - smoothstep(0.018, 0.10, length(fract(stars) - mix(vec2(0.2), vec2(0.8), offset)));
	sky_color += vec3(0.65, 0.76, 0.94) * star * step(0.83, seed) * smoothstep(0.01, 0.24, elevation);

	vec3 moon_direction = normalize(vec3(-0.42, 0.19, -1.0));
	float moon_distance = length(EYEDIR - moon_direction);
	float moon = 1.0 - smoothstep(0.030, 0.033, moon_distance);
	float halo = exp(-moon_distance * 17.0);
	sky_color += vec3(0.21, 0.22, 0.35) * halo;
	if (painted) {
		vec3 valley = texture(mountains, SKY_COORDS).rgb;
		// Blend the outer edges of the panorama on both sides of the longitude seam.
		float edge = min(SKY_COORDS.x, 1.0 - SKY_COORDS.x);
		valley = mix(valley, texture(mountains, vec2(1.0 - SKY_COORDS.x, SKY_COORDS.y)).rgb,
			0.5 * (1.0 - smoothstep(0.0, 0.045, edge)));
		sky_color = valley * mix(vec3(0.52, 0.63, 0.78), vec3(0.82, 0.83, 0.88), lantern_light);
		sky_color += vec3(0.10, 0.095, 0.072) * halo;
	}
	COLOR = mix(sky_color, vec3(0.94, 0.85, 0.66), moon);
}

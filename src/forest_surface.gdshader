shader_type spatial;
render_mode diffuse_burley;

uniform int surface_kind = 0;
uniform vec4 base : source_color;
uniform sampler2D grain_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 point;
varying vec3 local_pos;
varying vec3 axis_normal;
varying float upness;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float grain(vec3 p) {
	vec3 i = floor(p);
	vec3 f = smoothstep(vec3(0.0), vec3(1.0), fract(p));
	return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x),
		mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x),
		mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	vec3 offset = MODEL_MATRIX[3].xyz;
	if (surface_kind == 1) {
		VERTEX += NORMAL * (grain(VERTEX * 4.0 + offset) - 0.5) * 0.45;
	}
	point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_pos = VERTEX;
	axis_normal = NORMAL;
	upness = normalize(MODEL_NORMAL_MATRIX * NORMAL).y;
}

void fragment() {
	float broad = grain(point * 1.7);
	float fine = grain(point * 24.0);
	vec3 weights = pow(abs(normalize(axis_normal)), vec3(5.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 p = surface_kind == 1 ? point * 0.82 : local_pos * 0.72;
	vec3 detail = texture(grain_map, p.zy).rgb * weights.x + texture(grain_map, p.xz).rgb * weights.y + texture(grain_map, p.xy).rgb * weights.z;
	if (surface_kind == 0 || surface_kind == 3) {
		float ridges = grain(point * vec3(12.0, 0.85, 12.0) + broad);
		float furrow = smoothstep(0.24, 0.67, ridges);
		vec3 grain_color = mix(detail, vec3(dot(detail, vec3(0.28, 0.58, 0.14))), 0.16);
		ALBEDO = grain_color * (0.76 + 0.13 * furrow + 0.03 * fine);
		ROUGHNESS = 0.94;
	} else {
		float moss = smoothstep(0.52, 0.78, upness * 0.68 + broad * 0.44 + fine * 0.13);
		float strata = smoothstep(0.71, 0.88, grain(vec3(point.x, point.y * 9.0, point.z) + broad));
		vec3 mineral = detail * (0.78 + 0.28 * broad + strata * 0.12);
		ALBEDO = mix(mineral, detail * vec3(0.52, 0.77, 0.33), moss * (surface_kind == 2 ? 0.55 : 0.96));
		ROUGHNESS = mix(0.78, 1.0, moss);
	}
}

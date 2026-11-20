shader_type spatial;
render_mode cull_disabled, diffuse_burley;

varying float height;

void vertex() {
	height = UV.y;
	vec3 position = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	VERTEX.x += sin(TIME * 1.45 + position.x * 0.52 + position.z * 0.37) * height * height * 0.11;
	VERTEX.z += cos(TIME * 1.19 + position.z * 0.43) * height * height * 0.06;
}

void fragment() {
	float shadow_wash = mix(0.64, 1.0, smoothstep(0.08, 0.60, height));
	float midrib = (1.0 - smoothstep(0.018, 0.10, abs(UV.x - 0.5))) * height;
	ALBEDO = mix(vec3(0.14, 0.245, 0.105), vec3(0.41, 0.50, 0.21), height) * COLOR.rgb * shadow_wash;
	ALBEDO += midrib * vec3(0.045, 0.040, 0.015);
	EMISSION = ALBEDO * 0.13;
	ROUGHNESS = 1.0;
}

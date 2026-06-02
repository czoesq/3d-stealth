shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, blend_mix, cull_back;

uniform float occlusion_data[32];

varying float height;

void vertex() {
	height = clamp((VERTEX.y + 0.9) / 1.8, 0.0, 1.0);
}

void fragment() {
	float occ = occlusion_data[int(height * 31.0)];

	vec3 cam_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 view_dir = normalize(cam_pos - VERTEX);
	float rim = 1.0 - max(0.0, dot(normalize(NORMAL), view_dir));
	rim = pow(rim, 2.5);

	ALBEDO = vec3(1.0);
	ALPHA = rim * occ;
}

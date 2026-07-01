shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, blend_mix;

uniform vec4 albedo : source_color;

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
}

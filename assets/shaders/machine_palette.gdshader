shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Colours are stored in linear space, matching StandardMaterial3D albedo.
uniform sampler2D palette : filter_nearest, repeat_disable;

void fragment() {
	ALBEDO = texture(palette, vec2(UV2.x, 0.25)).rgb;
	if (OUTPUT_IS_SRGB) {
		ALBEDO = mix(1.055 * pow(ALBEDO, vec3(1.0 / 2.4)) - 0.055,
			12.92 * ALBEDO, lessThan(ALBEDO, vec3(0.0031308)));
	}
	vec3 finish = texture(palette, vec2(UV2.x, 0.75)).rgb;
	METALLIC = finish.r;
	ROUGHNESS = finish.g;
	SPECULAR = finish.b;
}

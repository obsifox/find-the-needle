shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D palette : filter_nearest, repeat_disable;
uniform sampler2D paint_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D steel_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rubber_detail : filter_linear_mipmap_anisotropic, repeat_enable;

void fragment() {
	vec4 base = texture(palette, vec2(UV2.x, 0.25));
	vec3 finish = texture(palette, vec2(UV2.x, 0.75)).rgb;
	vec4 detail = vec4(0.5);
	float strength = 0.0;
	if (base.a > 2.5) {
		detail = texture(rubber_detail, UV * 5.0);
		strength = 0.22;
	} else if (base.a > 1.5) {
		detail = texture(steel_detail, UV * 2.0);
		strength = 0.18;
	} else if (base.a > 0.5) {
		detail = texture(paint_detail, UV * 2.5);
		strength = 0.15;
	}
	ALBEDO = base.rgb * (0.92 + detail.a * 0.16);
	if (OUTPUT_IS_SRGB) {
		ALBEDO = mix(1.055 * pow(ALBEDO, vec3(1.0 / 2.4)) - 0.055,
			12.92 * ALBEDO, lessThan(ALBEDO, vec3(0.0031308)));
	}
	METALLIC = finish.r;
	ROUGHNESS = clamp(finish.g + (detail.b - 0.5) * 0.24, 0.16, 0.94);
	SPECULAR = finish.b;
	vec2 xy = (detail.rg * 2.0 - 1.0) * strength;
	NORMAL_MAP = vec3(xy * 0.5 + 0.5, sqrt(max(0.0, 1.0 - dot(xy, xy))) * 0.5 + 0.5);
}

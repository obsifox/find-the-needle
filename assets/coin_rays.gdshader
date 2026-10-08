shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// The light behind an Extra Life Coin as it is eaten: a card that always faces the
// camera, with two sets of rays turning against each other round a soft core.
// `strength` fades it and `spin` turns it. ExtraLifeCoin writes both every frame
// and hides the card whenever the coin is not being eaten.

uniform vec3 tint : source_color = vec3(1.0, 0.85, 0.45);
uniform float strength = 0.0;
uniform float spin = 0.0;

void vertex() {
	// Faces the camera and keeps the node's scale, which is how the coin grows it.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(MAIN_CAM_INV_VIEW_MATRIX[0],
		MAIN_CAM_INV_VIEW_MATRIX[1], MAIN_CAM_INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float rays = pow(max(sin(a * 8.0 + spin), 0.0), 8.0)
		+ 0.6 * pow(max(sin(a * 13.0 - spin * 1.3 + 1.7), 0.0), 12.0);
	float fall = 1.0 - smoothstep(0.1, 1.0, r);
	float core = exp(-r * r * 14.0);
	ALBEDO = tint * (rays * fall * fall * 1.4 + core * 1.2) * strength;
}

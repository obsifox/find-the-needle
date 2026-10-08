shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// One star glint on the NEW BEST banner over the hay stand. A four point star
// with a soft core, drawn on a camera facing quad. It only adds light, so where
// it crosses the gold text the text burns toward white.
// It is depth tested like the text, so a post that hides the banner hides the
// glints too. The text writes no depth, so it never hides its own glints.
// HaySellingStand tweens `power` up and back down and turns it a quarter turn
// with `spin` while it is lit. At power 0 it adds nothing.

uniform vec3 tint : source_color = vec3(1.0, 0.93, 0.66);
uniform float power = 0.0;
uniform float spin = 0.0;

void vertex() {
	// Faces the camera but keeps the node's scale, so the glint grows and
	// shrinks with the label it is parented to.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float c = cos(spin);
	float s = sin(spin);
	p = mat2(vec2(c, s), vec2(-s, c)) * p;
	float r = length(p);
	float core = exp(-r * r * 22.0);
	float rays = exp(-abs(p.x) * 38.0) * exp(-abs(p.y) * 3.2)
		+ exp(-abs(p.y) * 38.0) * exp(-abs(p.x) * 3.2);
	// Two shorter rays on the diagonals, so it reads as a sparkle, not a plus.
	vec2 d = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * p;
	float diag = exp(-abs(d.x) * 44.0) * exp(-abs(d.y) * 7.0)
		+ exp(-abs(d.y) * 44.0) * exp(-abs(d.x) * 7.0);
	float a = (core * 1.6 + rays + diag * 0.45) * smoothstep(1.0, 0.7, r) * power;
	ALBEDO = tint * a * 1.8;
}

shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// Laid over an Extra Life Coin while it is being eaten, as its material_overlay.
// It only adds light: `flash` washes the whole coin gold, and `sweep` runs a white
// glint diagonally across the face, from -1 at one edge to +1 at the other.
// ExtraLifeCoin writes both every frame and takes the overlay off when the coin is
// gone, so a coin nobody is eating draws with no overlay at all.

uniform vec3 tint : source_color = vec3(1.0, 0.8, 0.35);
uniform float flash = 0.0;
uniform float sweep = -3.0;
// The face in the mesh's own space, read off its bounds by ExtraLifeCoin.
uniform vec3 centre = vec3(0.0);
uniform float radius = 0.016;

varying vec3 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 p = (local.xy - centre.xy) / radius;
	float along = dot(p, vec2(0.7071, 0.7071));
	float glint = exp(-pow((along - sweep) * 3.5, 2.0));
	ALBEDO = tint * flash + vec3(1.0, 0.95, 0.8) * glint * 1.5;
}

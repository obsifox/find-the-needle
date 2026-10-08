shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back,
	shadows_disabled, fog_disabled;

// The red a building wears while it is standing where the next load will land.
// See LandingZone.
//
// Worn as a `material_overlay`, the way every hologram in this game tints itself,
// so it follows the machine's own surfaces rather than a box round them. The
// first version drew boxes off the collision shapes, through everything and with
// both faces showing, and a belt came out as a slab of solid red that hid the
// belt it was meant to point at.
//
// So it is thin, and it BREATHES rather than sits: a machine that pulses faintly
// red is still visibly the machine, and the pulse is what catches the eye from
// across the yard. Depth testing stays on, so a building only shows the tint on
// the faces that can actually be seen.

uniform vec3 colour : source_color = vec3(1.0, 0.16, 0.12);
/// Alpha at the bottom of the breath and at the top of it.
uniform float low : hint_range(0.0, 1.0, 0.01) = 0.06;
uniform float high : hint_range(0.0, 1.0, 0.01) = 0.34;
/// Seconds for one breath.
uniform float period = 1.4;

void fragment() {
	float breath = 0.5 - 0.5 * cos(TAU * TIME / period);
	ALBEDO = colour;
	ALPHA = mix(low, high, breath);
}

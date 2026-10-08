shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled,
	shadows_disabled, fog_disabled;

// A shockwave ring that bends the view behind it, thrown off the search head
// every time the detector beeps.
//
// Ported from mrsir8433's CC0 "Distortion" shader on godotshaders.com, which is
// a canvas_item full screen effect: the ring is a soft annulus, the pixels
// inside it are pulled toward the centre, and the red and blue channels are
// pulled by slightly different amounts so the edge fringes. All three of those
// are unchanged here.
//
// What changed is where the ring lives. A full screen version would have to be
// told, every frame, where on the screen the coil currently is, and it would
// keep distorting the sky after the tool was put away. This is the same maths
// on a quad instead, so the ring is a thing in the world sitting at the coil:
// the annulus is measured in the quad's own UV rather than in SCREEN_UV, and
// only the fetch is screen space. The quad is parented to the camera, so it
// follows the wand without anything having to project a position.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

/// How far the ring drags what is behind it, in screen widths.
uniform float strength : hint_range(0.0, 0.1, 0.001) = 0.012;
/// How far out the ring has travelled, in quad half widths. This is the one
/// the emitter animates: a ping is this going 0 to 1.
uniform float radius : hint_range(0.0, 1.0, 0.001) = 0.25;
/// How much further the red channel is dragged than the blue.
uniform float aberration : hint_range(0.0, 1.0, 0.001) = 0.425;
/// Thickness of the annulus, and how soft each of its two edges is.
uniform float width : hint_range(0.0, 0.5, 0.001) = 0.04;
uniform float feather : hint_range(0.0, 0.5, 0.001) = 0.135;
/// Overall opacity. The emitter fades this out as the ring runs away.
uniform float fade : hint_range(0.0, 1.0, 0.001) = 1.0;
/// A little light in the ring itself, so it still reads against a flat sky
/// where there is no detail for the distortion to bend.
uniform vec3 tint : source_color = vec3(0.55, 0.85, 0.65);
uniform float glow : hint_range(0.0, 2.0, 0.01) = 0.9;

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d) * 2.0;

	// The annulus: inside the outer edge and outside the inner one, both soft.
	float mask = (1.0 - smoothstep(radius - feather, radius, r))
		* smoothstep(radius - width - feather, radius - width, r);
	mask *= fade;
	if (mask <= 0.001) {
		discard;
	}

	vec2 dir = r > 0.0001 ? d / length(d) : vec2(0.0);
	vec2 offset = dir * strength * mask;
	vec2 abber = offset * aberration * mask;

	vec2 st = SCREEN_UV - offset;
	float red = texture(screen_tex, st + abber).r;
	float green = texture(screen_tex, st).g;
	float blue = texture(screen_tex, st - abber).b;

	ALBEDO = vec3(red, green, blue) + tint * glow * mask;
	ALPHA = mask;
}

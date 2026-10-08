shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled,
	shadows_disabled, fog_disabled;

// A shockwave ring thrown off the haystack scanner's magnet as it sweeps.
//
// The same effect as the metal detector's ping, and the same source: mrsir8433's
// CC0 "Distortion" on godotshaders.com, credited in assets/CREDITS.md. The maths
// below is unchanged from assets/detector_ping.gdshader, which is where the port
// from a canvas_item full screen shader to a quad in the world is explained.
//
// ONE LINE OF THE RENDER MODE IS DIFFERENT, and it is the whole reason this is a
// second file rather than the same shader with different parameters. The
// detector's rings carry `depth_test_disabled`, which is right for a tool held
// at the camera: nothing the player owns is ever in front of the coil, and
// drawing over everything saves the ring being clipped by the wand it came off.
//
// This ring is out in the yard, hanging off a machine with a steel gantry
// around it, and it has to be BEHIND things. Left depth-disabled it painted
// itself over the arch columns, over the cabinet, and over the player's own
// hands when they walked past the far side, which reads as a decal on the lens
// rather than as something happening at the magnet.
//
// `depth_draw_never` stays: the ring writes no depth of its own, so a stack of
// them does not fight over which is in front.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

/// How far the ring drags what is behind it, in screen widths.
uniform float strength : hint_range(0.0, 0.1, 0.001) = 0.010;
/// How far out the ring has travelled, in quad half widths. This is the one
/// the machine animates: a ping is this going 0 to 1.
uniform float radius : hint_range(0.0, 1.0, 0.001) = 0.25;
/// How much further the red channel is dragged than the blue.
uniform float aberration : hint_range(0.0, 1.0, 0.001) = 0.425;
/// Thickness of the annulus, and how soft each of its two edges is.
uniform float width : hint_range(0.0, 0.5, 0.001) = 0.04;
uniform float feather : hint_range(0.0, 0.5, 0.001) = 0.135;
/// Overall opacity. The machine fades this out as the ring runs away.
uniform float fade : hint_range(0.0, 1.0, 0.001) = 1.0;
/// A little light in the ring itself, so it still reads against a flat wall
/// where there is no detail for the distortion to bend. Cyan rather than the
/// detector's green: this machine's own instruments are cyan, and a ring in the
/// tool's colour would say the wrong thing about which one is looking.
uniform vec3 tint : source_color = vec3(0.35, 0.80, 0.95);
uniform float glow : hint_range(0.0, 2.0, 0.01) = 0.8;

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

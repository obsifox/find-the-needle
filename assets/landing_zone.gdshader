shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled,
	shadows_disabled, fog_disabled;

// The wall round where the next load of hay will land. See LandingZone.
//
// The wall follows the load's own outline, so it is a band built along that
// outline rather than a cylinder, and its UV is in METRES: x along the outline,
// y up the wall. The stripes are measured in those, so they keep the same slope
// and the same width round a wobble in the rim and on the smallest pile and on
// THE MOUNTAIN alike. The outline closes on itself at one point, which is why
// LandingZone hands this a pitch that fits a whole number of times round: any
// other pitch leaves a seam where the last stripe meets the first.
//
// Depth writing is off for the build grid's reason: the wall is see-through and
// has no business hiding anything behind it. Depth testing is left on, so a
// machine standing inside the zone is drawn in front of the far side of the wall
// rather than behind it.

/// Metres from the floor to the top of the wall.
uniform float height = 8.0;
/// Metres along the wall from one stripe to the next.
uniform float pitch = 1.2;
/// The share of each pitch that is stripe rather than gap.
uniform float duty : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float stripe_alpha : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float gap_alpha : hint_range(0.0, 1.0, 0.01) = 0.07;
/// Metres of solid band along the foot and along the top.
uniform float band = 0.3;
uniform float band_alpha : hint_range(0.0, 1.0, 0.01) = 0.5;
/// How far the wall breathes, as a share of its alpha. Slow and small: it is a
/// boundary to walk up to, not an alarm.
uniform float breath : hint_range(0.0, 1.0, 0.01) = 0.15;
uniform vec3 colour : source_color = vec3(0.95, 0.12, 0.10);

void fragment() {
	float along = UV.x;
	float up = UV.y;

	// Antialiased with the fwidth trick, for the build grid's reason: a stripe
	// the same weight at the far side of the wall as at the near.
	float d = (along + up) / pitch;
	float f = fract(d);
	float aa = max(fwidth(d), 1e-4);
	float stripe = smoothstep(0.0, aa, f) * (1.0 - smoothstep(duty, duty + aa, f));
	float alpha = mix(gap_alpha, stripe_alpha, stripe);

	float edge = max(1.0 - step(band, up), step(height - band, up));
	alpha = mix(alpha, band_alpha, edge);

	alpha *= 1.0 - breath * (0.5 + 0.5 * sin(TIME * 2.2));
	ALBEDO = colour;
	ALPHA = alpha;
}

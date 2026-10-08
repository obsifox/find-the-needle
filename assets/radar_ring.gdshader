shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Light on the ground under the satellite dish's marks: rings running outward
// from where to dig, a fixed rim at the edge of a Mk I circle, and the one
// shockwave the downlink throws off when it lands.
//
// Drawn on a PlaneMesh whose UV spans the whole square; the disc is the circle
// inside it. The dish tilts the plane to the slope of the pile it lies on, so
// it reads as light on the hay rather than as a sheet cutting into it.

uniform vec3 tint : source_color = vec3(0.45, 0.95, 1.0);
uniform float intensity = 1.0;
/// How many rings travel out at once, and how many cross a radius a second.
uniform float rings = 2.0;
uniform float speed = 0.5;
/// Where the fixed rim sits, as a share of the radius. 0 draws none.
uniform float edge = 0.0;
/// How much of a glow sits in the middle.
uniform float centre = 0.6;
instance uniform float fade = 1.0;
/// 0 to 1: a single ring at that radius instead of the travelling loop. Below 0
/// the loop runs. The downlink's landing drives this once, outward.
instance uniform float burst = -1.0;

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	if (r > 1.0) {
		discard;
	}
	float wave;
	if (burst >= 0.0) {
		float d = (r - burst) / 0.06;
		wave = exp(-d * d) * (1.0 - burst) * 2.0 + exp(-r * r * 6.0) * (1.0 - burst);
	} else {
		// A sharp front on the outside with its trail behind it, so the rings
		// read as going OUT from the spot rather than falling in on it.
		float t = fract(r * rings - TIME * speed);
		wave = pow(t, 9.0) * (1.0 - r * r);
	}
	float rim_line = 0.0;
	if (edge > 0.0) {
		float d = (r - edge) / 0.03;
		rim_line = exp(-d * d) * (0.75 + 0.25 * sin(TIME * 4.0));
	}
	float glow = exp(-r * r * 14.0) * centre;
	float edge_fade = 1.0 - smoothstep(0.85, 1.0, r);
	ALBEDO = tint * (wave + rim_line + glow) * edge_fade * intensity * fade;
}

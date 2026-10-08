shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled,
	shadows_disabled, fog_disabled;

// The lattice under a hologram, painted on whatever the aim is resting on.
//
// One flat quad that follows the aim point, with the lines worked out in WORLD
// space rather than in the quad's UV. That is the whole trick: the quad slides
// about under the crosshair every frame, and a pattern measured in its own UV
// would slide with it, so the lines would swim across the yard instead of
// staying nailed to the ground. Measured against world x and z they are the
// same lines every frame, and the quad is only a window onto them.
//
// Depth testing is left ON, so a lattice drawn at floor height disappears
// behind a machine standing on it rather than being painted over the top of
// one. Depth WRITING is off, because the quad is transparent and has no
// business occluding anything itself.
//
// Antialiasing is the fwidth trick: the distance to the nearest line, measured
// in pixels rather than in metres, so a line is the same weight underfoot as it
// is out at the far edge where the quad is nearly edge on. Without it the far
// half of the grid turns into a moire of half-lit pixels.

/// Spacing of the lattice, in metres. Cfg.BUILD_GRID_STEP.
uniform float step_size = 1.0;
/// Line weight, in pixels.
uniform float thickness : hint_range(0.5, 4.0, 0.1) = 1.3;
/// How hard the lines are drawn before the distance fade takes them.
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 0.5;
/// Where the piece is actually going: world x and z of the snapped aim point.
/// The crossing there is drawn brighter, because "which crossing did it pick"
/// is the one thing the player needs off this drawing.
uniform vec2 mark = vec2(0.0);
/// Radius of that brighter patch, in metres.
uniform float mark_radius = 0.32;
/// Where the fade starts and where it is finished, as a fraction of the quad's
/// half width. It never reaches the edge, so the grid has no rim: a hard edge
/// reads as a floating panel, and a fade reads as light thrown on the floor.
uniform float fade_in : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform vec3 line_tint : source_color = vec3(0.42, 0.78, 1.0);
uniform vec3 mark_tint : source_color = vec3(1.0, 0.94, 0.62);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Distance to the nearest line on each axis, in lattice units, divided by
	// how much a lattice unit moves across one pixel here.
	vec2 grid = world_pos.xz / step_size;
	vec2 near = abs(fract(grid + 0.5) - 0.5) / max(fwidth(grid), vec2(1e-6));
	float line = 1.0 - min(min(near.x, near.y) / thickness, 1.0);

	// Radial, off the quad's own UV, so the fade is a circle of light rather
	// than a square of grid.
	float r = length(UV - vec2(0.5)) * 2.0;
	float fade = 1.0 - smoothstep(fade_in, 1.0, r);

	float here = 1.0 - smoothstep(mark_radius * 0.6, mark_radius,
		length(world_pos.xz - mark));

	float alpha = max(line * opacity, here * 0.55) * fade;
	if (alpha < 0.003) {
		discard;
	}
	ALBEDO = mix(line_tint, mark_tint, here);
	ALPHA = alpha;
}

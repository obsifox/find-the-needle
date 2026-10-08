shader_type spatial;
render_mode cull_disabled, unshaded;

// Depth-only stand-in for the pile, rendered into the shadow map and nowhere
// else (the MeshInstance3D using it is SHADOW_CASTING_SETTING_SHADOWS_ONLY).
//
// Why this exists: the visible pile is 24 alpha-discarding shells, which is far
// too expensive to push through the shadow pass, and the strand crust on top of
// it only ever managed a lacy fringe. A 7 m haystack was therefore casting no
// real shadow at all and read as floating on the floor.
//
// Why it needs a shader rather than a plain material: the surface mesh it
// shares is SUNK along its normal by the depth available at each vertex, and
// hay_shells.gdshader extrudes back out from there, so the outermost visible
// shell lands on the real height-field surface. Drawing the raw mesh would cast
// the silhouette of a pile up to shell_depth smaller than the one on screen.
// This reproduces exactly where that outermost shell ends up.

uniform float shell_depth = 1.15;
// Pulls the proxy just inside its own visible surface. Without it the two are
// coincident and the pile shadow-acnes against itself; over a 20 m pile it
// changes the cast silhouette by nothing anyone can see.
uniform float inset = 0.12;
// Thin remnants already cast individual strand shadows from the crust. A solid
// proxy under them turns a sparse patch into a black cutout on the floor.
uniform float min_proxy_depth = 0.35;

void vertex() {
	VERTEX += NORMAL * (shell_depth * UV.x - inset);
}

void fragment() {
	if (shell_depth * UV.x < min_proxy_depth) {
		discard;
	}
	ALBEDO = vec3(0.0);
}

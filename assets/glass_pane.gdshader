shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// Glass, for the panes the yard is meant to look THROUGH.
//
// It exists because the same number means two different things in the two
// renderers, and the pulper's porthole is where that was finally noticed: the
// window was not dim in game, it was very nearly not drawn.
//
// A material table gives glass an `alpha`, and `pulper.py` sets it to 0.07. In
// Blender that feeds a Principled BSDF, where alpha attenuates the BASE LAYER
// and the specular reflection sits on top of it at full strength, so a pane at
// 0.07 still catches the sky and reads as glass. Godot's StandardMaterial3D
// with TRANSPARENCY_ALPHA multiplies the WHOLE shaded fragment by alpha, the
// highlight included, so the same 0.07 erases 93% of the only thing that was
// saying "glass" and leaves an empty hole with a ring bolted round it.
//
// So the two numbers are separated. `base_alpha` is how much of the pane is
// there when you are square in front of it, and it is the game's number rather
// than Blender's for the reason above. `edge_alpha` is how much is there at a
// grazing angle, which is what puts a bright shoulder on anything curved: the
// water pipe's glass spool is a tube and lights up all down both sides, and
// even a flat pane picks it up as you walk past rather than staying a
// featureless film.
//
// WHAT THIS IS NOT: refraction, a mirror, or a second depth pass. The porthole
// exists so a player can watch the paddles turn, and `porthole()`'s own
// docstring is emphatic that a window which becomes "a mirror of the sky with
// nothing readable behind it" has failed at the one job it has. Everything here
// is tuned to stay under that.

uniform vec3 tint : source_color = vec3(0.72, 0.80, 0.78);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.16;
uniform float edge_alpha : hint_range(0.0, 1.0) = 0.70;
uniform float edge_power : hint_range(0.5, 8.0) = 2.5;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.03;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	// Schlick's angle term: 0 square on, 1 edge on. NORMAL and VIEW are both in
	// view space here and both already unit length, but the interpolation
	// across a smooth-shaded rim leaves NORMAL slightly short of it, and that
	// error lands straight on the exponent.
	float grazing = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float f = pow(grazing, edge_power);

	ALBEDO = tint;
	ROUGHNESS = roughness_amount;
	METALLIC = 0.0;
	SPECULAR = specular_amount;
	ALPHA = clamp(mix(base_alpha, edge_alpha, f), 0.0, 1.0);
}

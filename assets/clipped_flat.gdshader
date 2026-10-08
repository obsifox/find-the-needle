shader_type spatial;
// A flat painted surface that can be cut off at a height.
//
// WHY THIS EXISTS
// ---------------
// `needle_cabinet.gd` slides its ending panel down into the case opening, and
// everything above the opening has to be thrown away for the length of the drop
// -- otherwise the part that has not arrived yet hangs in the air over the
// cornice. `stand_surface.gdshader` grew a `clip_above` uniform for exactly
// that, and the panel's WOOD is one of its textured surfaces, so the slab
// clipped correctly on the first try.
//
// The button, its brass ring, the label card and the engraving are not. They
// are FLATS -- painted colours with no scan behind them -- and `_make_surface`
// builds those as `StandardMaterial3D`, which has no shader and therefore no
// way to be told about a plane. So the slab came down neatly while a large red
// button floated above the furniture on its own.
//
// This is the flat half of that material table, restated as a shader so the two
// can be clipped together. It is deliberately the SAME four properties
// `_make_surface` sets on a flat and nothing else: this is not a better
// material, it is the same one with a plane through it.
uniform vec3 albedo : source_color = vec3(1.0);
uniform float rough : hint_range(0.0, 1.0) = 0.6;
uniform float metal : hint_range(0.0, 1.0) = 0.0;
uniform float spec : hint_range(0.0, 1.0) = 0.4;
uniform float emit_strength = 0.0;
// Matches `stand_surface.gdshader`: a WORLD-space plane, so it stays horizontal
// whatever yaw the cabinet was placed at, and a default far above anything in
// the game so an unset material renders whole.
uniform float clip_above = 1000.0;

void fragment() {
	if ((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y > clip_above) {
		discard;
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	if (emit_strength > 0.0) {
		EMISSION = albedo * emit_strength;
	}
}

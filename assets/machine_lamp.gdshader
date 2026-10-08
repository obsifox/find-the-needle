shader_type spatial;
#ifdef LAMP_TWO_SIDED
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
#else
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
#endif

// A lamp on a machine: the flat emissive a material table describes, drawn the
// way StandardMaterial3D draws it, with its brightness and colour set per
// MACHINE.
//
// Every machine of a model wears ONE copy of each of its materials, because
// Forward+ only draws identical mesh and material pairs as one instanced call
// and a copy made per machine is a pair nothing else shares (1,554 distinct
// pairs for 1,770 generator surfaces in the 19 Sep yard). A lamp is the one
// surface that has to differ between two machines standing side by side, so
// what differs cannot live on the material. It lives here, on the instance,
// and `HayCompressor.light_lamps` sets it on the machine's own mesh.
//
// The rest is `make_material`'s flats branch copied across by
// `HayCompressor.lamp_material`, so a lamp nobody has lit yet looks exactly
// like the StandardMaterial3D it replaced. That function compiles this file
// again with LAMP_ALPHA and LAMP_TWO_SIDED set for a see-through flat (the
// scanner's beam curtain and its beacon lens), which is what
// StandardMaterial3D's transparency and cull switches were.

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.4;
uniform vec3 emission : source_color = vec3(0.0);
// The table's own `emit`, for a lamp no machine has set.
uniform float emission_energy = 1.0;

// The machine's lamp, as StandardMaterial3D's `emission_energy_multiplier`.
// Negative is "not set", which falls back to the table's. One per mesh: two
// lamps on one mesh would share it, and none of the models do that.
//
// The slots are stated because the slurry, the pour and the steam carry
// instance uniforms too, and two materials on one mesh that both claim slot 0
// under different names overwrite each other.
instance uniform float lamp_energy : instance_index(0) = -1.0;
// The machine's lamp colour, for the albedo and the glow both, as the scanner
// writes them: its alpha is only "set" (1) or "not set" (negative), and the
// surface keeps the material's own alpha either way. Sent as a Color, so it
// arrives converted to linear the way `albedo` and `emission` are.
instance uniform vec4 lamp_colour : instance_index(6) = vec4(0.0, 0.0, 0.0, -1.0);

void fragment() {
	bool tinted = lamp_colour.a >= 0.0;
	ALBEDO = tinted ? lamp_colour.rgb : albedo.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
	EMISSION = (tinted ? lamp_colour.rgb : emission)
		* (lamp_energy < 0.0 ? emission_energy : lamp_energy);
#ifdef LAMP_ALPHA
	ALPHA = albedo.a;
#endif
}

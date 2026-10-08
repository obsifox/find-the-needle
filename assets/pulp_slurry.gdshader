shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// The mash lying in the pulper's drum, and the only surface in this yard that
// MOVES OF ITS OWN ACCORD.
//
// Everything else that looks alive here is a rigid part being turned or slid by
// the game: a rotor, a gate, a pulley. The charge is not a part. It is a body
// of liquid with a drum turning through it, and modelled at rest it read as a
// solid lump wedged in the barrel that dropped a step whenever a batch drained.
// The porthole exists so a player can put their face against it, so the one
// thing behind it that should never be still was.
//
// WHY THIS IS NOT ON stand_surface.gdshader. That file argues, in its note on
// `coat`, against splitting a second shader off for one machine, and it is
// right every time the extra work happens in the fragment stage. This does not:
// it needs a VERTEX stage, and putting one there would run on every fence post,
// wall panel and belt frame in the yard to serve one face inside one drum.
//
// THE WAVES MUST DIE AT THE RIM, and that is a hard constraint rather than a
// preference. `pulper.py` tessellates the waterline into a grid without welding
// its border to the shell and the end caps, so every vertex along the boundary
// is a T junction: anything that lifts the rim tears the mash away from the
// drum wall. `edge_fade` is what holds it down, and it is also what a contained
// liquid does, so the constraint and the look ask for the same thing.

// TAU IS THE LANGUAGE'S, and declaring one here is a compile error rather than
// a redundancy: Godot's shading language ships PI, TAU and E as built-in
// constants, and a shader that redefines one fails to build. A ShaderMaterial
// whose shader failed to build does not fall back to something close; it draws
// as flat unlit white. That is what this surface was doing, and the symptom
// looked like a modelling fault rather than a compile error, because a flat
// white plane with a hard edge in a drum reads as a card somebody slid in.

uniform vec3 tint : source_color = vec3(0.66, 0.42, 0.02);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.95;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.44;

// The swell: metres of rise, metres between crests, metres a second.
uniform float amplitude = 0.016;
uniform float wavelength = 0.34;
uniform float wave_speed = 0.55;
// How far below the waterline the motion has died out, in metres. Only the top
// skin of the solid moves; the curved bottom sitting in the bore does not.
uniform float fade_depth = 0.09;

// The geometry the mask is built from, all in the mesh's OWN space and all
// pushed from GDScript off the mesh's AABB rather than typed here, so a drum
// rebuilt at another size carries its waterline with it.
//
// The mesh is the LOWER HALF of the bore with a flat top on it and its origin
// on the inner floor, so these three are the bore itself: `surface_y` is the
// rise from the floor to the axis, which is the bore's radius, and `half_x` is
// that same radius across. They are kept as two numbers rather than one so a
// bore that is not round still works.
uniform float surface_y = 0.44;
uniform float half_x = 0.44;
uniform float half_z = 0.67;

// How full, 0 at the floor and 1 at the axis, which is where the mesh's own flat
// top sits.
//
// THIS IS WHY THE FILL IS NOT A SCALE ANY MORE, and it is worth the uniform.
// Squashing this mesh on Y turns the bore's circular section into an ELLIPSE,
// and an ellipse that touches the circle at the floor and at the waterline
// BULGES OUT OF IT everywhere in between: at 40% full the bulge is 18% of the
// bore's radius, which is 85 mm of mash standing outside a drum with a 20 mm
// wall. It was on screen as a smooth band of cream lying along the outside of
// the barrel, and it had been there at every fill but full since the mash was
// first modelled. The bath got away with it because at 86% the bulge is 17 mm
// and stays buried inside the wall.
//
// Cutting instead of squashing keeps every point of the body on the bore it was
// built from, at every fill. See `vertex`.
// PER MACHINE, like `flow` and `liquor` below: every pulper wears the one copy
// of this material its model has, so what differs between two drums side by
// side is set on each drum's own mesh (see HayCompressor.shared_material).
instance uniform float fill : instance_index(1) = 1.0;

// 0..1, and it is `HayPulper.drive()`. A pulper with a dead wire or an empty
// pipe is standing still, and so is what is inside it.
instance uniform float flow : instance_index(2) = 0.0;

// The bath's colour and opacity, set by the machine as the charge is beaten:
// `tint` and `base_alpha` in one, for the same reason `fill` is per machine. A
// negative alpha means "not set", and the surface falls back to the material's
// own pair, which is what the bed under it wears. Sent as a Color, so it
// arrives converted to linear the way `tint` is.
instance uniform vec4 liquor : instance_index(3) = vec4(0.0, 0.0, 0.0, -1.0);

// Half the bore's width at a height above its floor. The bore is the ellipse
// through (0, 0) and (+-half_x, surface_y), so this is that section solved for
// x, and it is the one piece of geometry the cut below needs.
float bore_half(float h) {
	float r = max(surface_y, 1e-4);
	float dy = clamp(h, 0.0, r) - r;
	return half_x * sqrt(max(1.0 - (dy * dy) / (r * r), 0.0));
}

// How much of the surface is allowed to move, 0..1. Zero at the drum wall, zero
// below the skin, one in the middle of the pool. Measured against the WATERLINE
// the cut left rather than against the mesh's own top, or the swell would die
// at a height the liquid no longer reaches.
float wave_mask(vec3 v, float wy, float hx) {
	float ex = 1.0 - pow(clamp(abs(v.x) / max(hx, 1e-4), 0.0, 1.0), 4.0);
	float ez = 1.0 - pow(clamp(abs(v.z) / max(half_z, 1e-4), 0.0, 1.0), 4.0);
	float skin = smoothstep(wy - fade_depth, wy, v.y);
	return ex * ez * skin;
}

// Two crossed swells. The strong one runs along X, which is the way the rotor
// drags the mash round the bore; the second is turned across it and travels
// back at a different rate, so the two never sit still against each other and
// the pattern does not visibly repeat in the two seconds of a batch.
float wave_height(vec3 v, float t) {
	float k = TAU / max(wavelength, 1e-4);
	float w = k * wave_speed;
	float a = sin(k * v.x + w * t);
	float b = sin(k * (0.62 * v.z + 0.38 * v.x) - w * 0.83 * t);
	return amplitude * (0.62 * a + 0.38 * b);
}

void vertex() {
	// THE CUT. Every point above the waterline is brought down onto it and drawn
	// in to the width the bore has THERE, so the body is always the bore's own
	// section filled to a level: the wetted shell keeps the curve it was built
	// with, the flat top narrows to the waterline's chord, and nothing ever
	// leaves the barrel. See the note on `fill` for what the old scale did.
	//
	// Points at or below the line are left exactly where the model put them,
	// which is what makes this cheap: at a full drum it is a no-op.
	float wy = surface_y * clamp(fill, 0.0, 1.0);
	float rim = bore_half(wy);
	if (VERTEX.y > wy) {
		// The shell collapses onto the waterline's rim, the lid shrinks to the
		// same chord, and anything caught between them (the straw) goes with the
		// stuff it is floating in.
		VERTEX.x *= rim / max(bore_half(VERTEX.y), 1e-4);
		VERTEX.y = wy;
	}

	float m = wave_mask(VERTEX, wy, rim) * flow;
	if (m > 0.0001) {
		float t = TIME;
		// VERTEX is in model space, so a lift written here is squeezed by whatever
		// the node is scaled by. The fill is a cut now and not a scale, so this is
		// 1.0 in practice, and it is kept because a node scaled for any other
		// reason would otherwise change the size of the swell.
		float sy = length(MODEL_MATRIX[1].xyz);
		float h = wave_height(VERTEX, t) * m / max(sy, 1e-4);
		VERTEX.y += h;

		// The normal has to follow or the surface stays lit like a flat plate
		// and the whole thing reads as a texture sliding over a lid. Sampled
		// rather than differentiated: the mask is in the height as well, and
		// its derivative is not worth carrying for a 16 mm swell.
		float d = 0.02;
		vec3 dx = vec3(VERTEX.x + d, VERTEX.y, VERTEX.z);
		vec3 dz = vec3(VERTEX.x, VERTEX.y, VERTEX.z + d);
		float hx = wave_height(dx, t) * wave_mask(dx, wy, rim) * flow / max(sy, 1e-4);
		float hz = wave_height(dz, t) * wave_mask(dz, wy, rim) * flow / max(sy, 1e-4);
		NORMAL = normalize(mix(NORMAL,
			normalize(vec3(-(hx - h) / d, 1.0, -(hz - h) / d)),
			clamp(NORMAL.y, 0.0, 1.0)));
	}
}

void fragment() {
	bool driven = liquor.a >= 0.0;
	ALBEDO = driven ? liquor.rgb : tint;
	ROUGHNESS = roughness_amount;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ALPHA = driven ? liquor.a : base_alpha;
}

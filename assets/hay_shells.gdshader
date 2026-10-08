shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;

// Shell-textured hay.
//
// The pile surface is drawn N times, each copy pushed further out along the
// surface normal. A straw mask decides which fragments survive on each copy:
// the further out the shell, the higher the threshold, so fewer strands reach
// it. The result is genuine volumetric depth -- you look between the strands
// and see more strands behind them, fading into darkness, with no flat backing.
//
// The mask is PROCEDURAL, not a photo. A photographed thatch scan has
// large-scale dark blobs in it; tiled over metres, any blob makes every shell
// discard at once and punches a visible hole clean through the pile. A hash
// grid has uniform statistics by construction, so that cannot happen.

uniform int shell_count = 24;
uniform float shell_depth = 1.15;        // how deep the straw layer goes, metres
uniform float strands_per_m = 46.0;      // hash grid resolution
uniform float thickness = 0.62;          // strand fatness within its grid cell
uniform float height_bias = 1.25;        // >1 makes outer shells thin out faster
uniform vec3 hay_light : source_color = vec3(0.56, 0.305, 0.115);
uniform vec3 hay_dark : source_color = vec3(0.15, 0.062, 0.017);
uniform float core_shade = 0.72;         // brightness of the deepest layer
uniform bool debug_flat = false;         // flat-shade to spot real holes

// GLOSS AND OCCLUSION -- what separates a pile of straw from a brown carpet.
//
// Measured against assets/reference/, over the pile's own pixels:
//
//                              p1      p99    ratio   frac < 0.05
//   reference (5M straws)     0.008   0.776    96x       17.5%
//   this shader, before       0.053   0.510   9.7x        0.9%
//
// A sixth of the reference is essentially BLACK -- that is where the depth
// reads from. Nothing here could get near it, for two reasons that were both
// deliberate and both applied to the whole pile instead of the case they were
// added for: an emission floor that self-lit every shell, and a core_shade that
// stopped the deepest layer 28% below the surface. Both exist to keep a DUG
// face from going black, and both now ride on UV.y -- full strength on a
// cropped face, nothing at all out on the open pile.
//
// AO does the rest. SSAO runs at a 1.4 m radius because that is the scale that
// grounds the room, so it cannot see a 9 mm gap between two straws. The shader
// knows exactly how deep a fragment sits without having to search for it.
uniform float ao_deep = 0.06;            // ambient reaching the deepest layer
uniform float ao_light_affect = 0.45;    // how much of that also cuts direct sun
// Straw has a waxy cuticle and is genuinely glossy; the reference sparkles
// because of it. Roughness varies per strand so the pile glints in scattered
// points rather than sheeting all at once.
//
// THE CEILING ON ALL OF THIS IS THE SKY, not the sun. Ambient and reflections
// both come off the HDRI cubemap, and straw presents nothing but grazing angles
// -- so a smooth dielectric here does not catch a glint, it mirrors the whole
// dome. At 0.30 roughness and 0.7 anisotropy the pile came out silver: every
// strand wearing a full-length white streak, measured as saturation falling
// from 0.53 to 0.30 against a reference that sits at 0.76. Rough enough to
// scatter, glossy enough to catch the sun, and the anisotropy kept low enough
// to stay a highlight rather than a stripe.
uniform float gloss_rough_lo = 0.58;
uniform float gloss_rough_hi = 0.88;
uniform float gloss_specular = 0.26;
// The highlight runs ALONG the strand, which is what reads as a stalk rather
// than a chip. TANGENT already carries the growth direction (see hay_chunk.gd),
// so the anisotropy needs no extra vertex data.
uniform float anisotropy = 0.20;
// Some straw is grey-tan and some is warm gold. One hue for all of it is a
// large part of why the mass reads as one material instead of a million stalks.
uniform float hue_jitter = 1.0;
// Shell texturing grows strands along the surface NORMAL. On the steep faces
// that reads as straw poking out of the pile, but where the surface is flat --
// the skirt around the base -- it stands every strand bolt upright and the rim
// turns into stubble. Leaning the stack sideways as it rises turns those
// columns into straws lying over, which is what loose hay actually does.
uniform float lean = 0.55;               // how far the stack slews over, in cells
uniform float lean_patch = 0.45;         // size of a same-direction clump, 1/m
// Discarding the stack outright on shallow ground looked like the fix for the
// bristly rim, but it cut far more than the rim: transmission at 10 m went from
// 0.05% to 13.6%. The stack is already compressed there by UV.x, so shortness
// is handled -- it was only ever the upright ANGLE that read wrong, and the
// lean above is what fixes that. Left at 0; raise only with --transmission open.
uniform float min_depth = 0.0;
// The runtime enables one solid innermost layer as a safety net. The other
// layers remain procedural straw, but this prevents a large cleared patch from
// exposing a black interior after plucking or digging. It is only one of the
// 24 layers, so the visible surface keeps its volumetric depth.
uniform bool solid_core = true;

// WHAT DOES NOT FIX THE DUG-HOLLOW FAN
//
// A hollow dug into the pile shows a dark radial starburst. Reproduce it with:
//   godot --path . -- --capture --reproshot --usesave
// Every one of these was measured against that shot and --transmission, on one
// pile, and every one failed:
//
//   curvature suppression (K=5)   3m 2.64% -> 13.19%   fan unchanged
//   shorter stack (1.15 -> 0.40)  3m 2.64% -> 1.63%    fan unchanged
//   thinner strands (0.62->0.50)  3m 2.64% -> 1.70%    coverage is pi*(t/2)^2
//
// Two of them DID help opacity a lot and are now the defaults -- 115 strands/m
// at the original 0.62 coverage, grown along a normal smoothed over 12 cells:
//
//                                 3m 2.64% -> 0.247%   10m 0.093% -> 0.000%
//
// but neither fixes the fan.
//
// The reason none of them work: in a concave hollow the view direction is
// roughly along the axis the strands grow on, so what is on screen is their END
// CAPS. That is inherent to shell texturing, not a parameter.
//
// WHAT DID FIX IT
//
// Not paying for instanced strands, which is what this note used to conclude --
// the crust cannot be made denser per cell than the LOD's global cap, so the
// coverage simply is not available. Instead: leave nothing sticking out to look
// at. HayChunk caps the stack's LENGTH wherever the pile has been dug into,
// sinking the mesh by the same amount so the outermost shell still lands on the
// surface, and the straw that survives closes up (`bias` and `thick` below) to
// hold the opacity the length was providing. Out on the open pile the cap does
// nothing at all, measured: see-through is identical to the pixel.
//
// Both halves are load-bearing, and each one alone is its own artifact. Crop
// without sinking to match, or crop twice, and the stack stops short of the
// surface -- a dug wall becomes a black cave, which --transmission cannot see
// because what shows through is the pile's own far side and not the backdrop.
// Crop without closing the straw up, and the face goes bare instead.

varying float v_shell;                   // 0 at the core, 1 at the real surface
varying vec3 v_world;
varying vec3 v_normal;                   // world-space surface normal, for shading
varying vec3 v_grow;                     // direction strands grow, smoothed
varying float v_offset;                  // how far this shell was pushed out

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
			 dot(p, vec3(269.5, 183.3, 246.1)),
			 dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

void vertex() {
	// Instances of this MultiMesh are shells, not scattered objects: every
	// instance shares the surface mesh and differs only in how deep it sits.
	//
	// The mesh is sunk along the normal by the available depth; shells extrude
	// back out along it, so the outermost shell lands exactly on the real
	// surface however steep the face is.
	//
	// UV.x carries how much depth is actually available at this vertex, so the
	// stack always stays inside the pile no matter how thin it gets.
	v_shell = float(INSTANCE_ID) / max(float(shell_count - 1), 1.0);
	// UV.x ALONE. It already carries the cropped depth -- HayChunk works out how
	// much stack this spot is allowed and sinks the mesh by exactly that, so the
	// outermost shell lands on the real surface whatever the crop did.
	//
	// UV.y used to multiply in here as well, as a second suppression term, and
	// leaving it in after UV.y was repurposed cropped every dug face TWICE: a
	// stack cut to 3% of its length came out at 0.1% of it, one millimetre of
	// straw standing off a mesh sunk three centimetres. The gap between the two
	// is a window onto the unlit inside of the pile, which is what a dug wall
	// then read as -- a black cave. --transmission cannot see it, because what
	// shows through is the pile's own far side rather than the backdrop.
	v_offset = v_shell * shell_depth * UV.x;
	// CUSTOM0 carries the smoothed growth direction; see hay_chunk.gd. Not
	// TANGENT: on flat dug ground the growth direction IS the normal, and a
	// tangent parallel to the normal gives Godot a zero cross product to build
	// the anisotropy binormal from. That was the black blob with the white halo.
	vec3 grow = normalize(CUSTOM0.xyz);
	VERTEX += grow * v_offset;
	v_grow = normalize((MODEL_MATRIX * vec4(grow, 0.0)).xyz);
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// The shell is deliberately two-sided: a dug height-field wall can face
	// either direction as the player walks around the hollow. Godot keeps the
	// original vertex normal for a back-facing triangle when culling is disabled,
	// so the back side can receive a zero-light result and turn into a black
	// patch. Flip the shading normal for that face while leaving the procedural
	// strand direction alone. This preserves the same silhouette from both
	// sides and makes the excavated wall respond to the same light as the outer
	// face.
	NORMAL = normalize(NORMAL) * (FRONT_FACING ? 1.0 : -1.0);

	// Every shell, innermost included, keeps only the straw that reaches that
	// far out. Nothing here is a solid surface.
	//
	// There used to be a `discard` on UV.y here, from the version of this that
	// suppressed the stack in the shader. UV.y is a SHADING term now -- the crop
	// happens on the CPU, where the mesh can be lifted by the same amount it is
	// cropped by (see HayChunk._rebuild_surface_mesh). Discarding on it as well
	// would cut a hole in exactly the faces the crop is there to fix.
	if (min_depth > 0.0 && UV.x < min_depth) {
		discard;
	}

	float tone = 0.5;
	// The third component of the cell hash, which nothing was using. It is the
	// strand's identity for everything that is not its brightness: its hue and
	// how glossy it is. Both have to come off the SAME per-strand value as
	// `tone` or the variation stops being per-strand and turns into noise.
	float grain = 0.5;
	if (v_shell > 0.001 || !solid_core) {
		vec3 n = normalize(v_grow);
		// Back-project to where this shell started on the surface. Every shell of
		// one strand lands on the same point, so that point is the strand's
		// identity -- and it works whatever way the surface faces.
		//
		// The grid used to be indexed by world XZ, which has no vertical
		// variation at all: on the near-vertical wall around the pile's edge
		// every height mapped to the same cell and the straws smeared into
		// upright streaks. A 3D grid has no preferred axis.
		vec3 base = v_world - n * v_offset;

		// Lean along the surface rather than in world XZ, so the slew is sideways
		// on a wall just as it is on flat ground. Constant over roughly a metre,
		// so straws lie in clumps the way real straw settles.
		vec3 r = hash33(floor(base * lean_patch)) - 0.5;
		vec3 tangent = r - n * dot(r, n);
		if (dot(tangent, tangent) > 1e-6) {
			base -= normalize(tangent) * (v_shell * lean / strands_per_m);
		}

		vec3 g = base * strands_per_m;
		vec3 cell = floor(g);
		vec3 h = hash33(cell);

		// A CROPPED stack has to earn its opacity from density, because it has
		// no length left to earn it from.
		//
		// UV.y is how much of the stack survived (1 out on the open pile, a few
		// hundredths on a face that has been dug into). Cropping alone fixed the
		// end-cap starburst and then replaced it with a worse problem: a dug
		// wall went see-through to the unlit inside of the pile and read as a
		// black cave. The instanced crust cannot cover it -- per-cell density is
		// capped by the LOD, see HayChunk._write_cell -- so the straw that is
		// left has to close up instead.
		//
		// Two knobs, both no-ops at full length. Nearly every strand reaches the
		// outermost shell rather than a quarter of them, and each one is fatter.
		// Which is also what a spade-cut face of straw actually looks like: a
		// dense mat of cut ends, not a thinning fuzz.
		float bias = mix(0.30, height_bias, UV.y);
		float thick = mix(thickness * 1.55, thickness, UV.y);

		// A strand only exists on shells below the height it reaches.
		float reach = pow(h.x, bias);
		if (reach < v_shell) {
			discard;
		}
		// Cross-section measured in the plane of the surface, with the normal
		// component projected out, so a strand is round from every direction.
		vec3 f = fract(g) - 0.5 - (h - 0.5) * 0.45;
		f -= n * dot(f, n);
		if (dot(f, f) > thick * thick * 0.25) {
			discard;
		}
		tone = h.y;
		grain = h.z;
	}

	// Godot's shading language does not allow 'return' in a processor function,
	// and this used to early-out through one. The whole shader failed to compile
	// because of it, so the pile has been falling back to a default material and
	// none of the shell depth below was ever on screen.
	if (debug_flat) {
		ALBEDO = vec3(1.0, 0.0, 1.0);
		EMISSION = vec3(1.0, 0.0, 1.0);
	} else {
		// Deeper shells are darker, which is what turns the gaps between strands
		// into readable depth rather than a flat backing.
		//
		// How dark the deepest one goes has to follow the CROP, though. v_shell
		// still runs 0 to 1 across the stack however short the stack is, so a
		// face cropped to a tenth of its length was shading straw sitting two
		// centimetres under the surface as if it were a metre down -- which
		// turned every dug hollow into a black pit. At full length this is the
		// old core_shade exactly.
		float floor_shade = mix(1.0, core_shade, UV.y);
		float depth_shade = mix(floor_shade, 1.0, v_shell);
		vec3 hay = mix(hay_dark, hay_light, tone);
		// Cool grey-tan at one end of the hash, warm gold at the other. Applied
		// before the depth shade so a deep strand keeps its own hue rather than
		// every deep strand converging on the same brown.
		hay *= mix(vec3(0.95, 0.99, 1.09), vec3(1.09, 1.00, 0.82),
				mix(0.5, grain, hue_jitter));
		ALBEDO = hay * depth_shade;
		// Deep shells can be viewed from inside a hollow, where direct light and
		// sky fill are legitimately close to zero. Give the material a restrained
		// self-lit floor so that an excavated wall stays brown hay instead of
		// becoming a black patch.
		//
		// GATED ON THE CROP. This is the safety net for a DUG face, and paying
		// for it everywhere is what stopped the pile ever having a black pixel
		// in it: at full length it was self-lighting the deepest layer at 42% of
		// its own albedo, which is a floor no amount of occlusion can get under.
		// UV.y is 1 on the open pile and a few hundredths on a cut face, so this
		// is now off where it was doing harm and unchanged where it was doing
		// its job.
		EMISSION = hay * mix(0.42, 0.12, v_shell) * (1.0 - UV.y);
		// Ambient is most of what reaches straw, so occluding it is the whole
		// depth cue. Same crop gate as the emission above: a dug face keeps its
		// light, the open pile gets its gaps back.
		float ao = mix(mix(1.0, ao_deep, UV.y), 1.0, v_shell);
		AO = ao;
		AO_LIGHT_AFFECT = ao_light_affect;
		ROUGHNESS = mix(gloss_rough_lo, gloss_rough_hi, grain);
		// Specular occlusion, by hand. Godot's AO only attenuates diffuse
		// ambient, and the sky reflection is the brighter half of what a glossy
		// surface picks up -- so without this the deep shells go dark in diffuse
		// and then get the whole sky dome back as a sheen, which is the one
		// thing the shells must not do: they are the inside of the pile.
		SPECULAR = gloss_specular * ao;
		// TANGENT is the growth direction, so the default flow already points
		// along the strand and the highlight lies across it -- the same term
		// that makes hair and brushed metal read as fibres.
		ANISOTROPY = anisotropy;
		ANISOTROPY_FLOW = vec2(1.0, 0.0);
		// Straw is thin enough to bleed a little light through from behind, and
		// the sun here arrives through a slot straight above the pile, so the
		// far rim is exactly where this shows.
		BACKLIGHT = vec3(0.18, 0.11, 0.045) * v_shell;
	}
}

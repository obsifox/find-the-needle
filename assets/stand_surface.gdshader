shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// The selling stand's surfaces, evaluated exactly as the .blend evaluates them.
//
// The model ships without its textures baked in: every scan it uses is already
// on disk for the warehouse, so embedding them would put a second copy of ten
// megabytes inside the .glb. Instead the build writes its material table to
// hay_selling_stand_materials.json and the game rebuilds the surfaces here.
//
// That only works if this shader is the same function Blender's node graph is,
// which is why it does the two odd-looking things it does:
//
//   * DESATURATE, THEN MULTIPLY BY A TINT. Every colour on the building is a
//     darkening of a photograph rather than a flat fill, so the dirt and wear
//     in the albedo survive into the final colour. It is what lets a scan be
//     chosen for its surface and not its hue -- the belt rubber is a brick-red
//     running track pulled to near-black, and the frame is blue plate.
//
//   * REMAP roughness into an explicit range instead of scaling it. Scaling a
//     map that is already dark can only make a surface glossier, which is how
//     painted machine steel ends up looking like wet plastic. Stating the range
//     says outright how matt the dullest and shiniest parts get.
//
// UVs arrive in METRES from the exporter, so `per_metre` is repeats per metre of
// real surface and one number holds a texture at the same physical size across
// parts of wildly different dimensions.

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_ao : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float per_metre = 1.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float rough_min : hint_range(0.0, 1.0) = 0.4;
uniform float rough_max : hint_range(0.0, 1.0) = 0.9;
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.0;
uniform float normal_strength : hint_range(0.0, 4.0) = 1.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.0;

// A THIN SMOOTH SPECULAR LAYER OVER THE DIFFUSE, which is physically what a
// film of water is, and the one thing on this shader that is not about shed
// machinery.
//
// It is here for `hay_pulp.glb`, the only wet object in the game.
// `assets/blender/_build/pulp.py` builds every mash and fibre material with a
// coat because `tex.pbr` has no input for one, and passes the pair out in the
// material table as `coat`, so the .blend and the game put the SAME film on
// rather than two people's idea of one. A pulp without it is a dark wad.
//
// Zero by default, which is every other surface in the yard: steel, timber and
// straw are all dry and none of them changes by a pixel. The cost of carrying
// it here rather than in a second shader is one clearcoat lobe per light on
// surfaces that set it to nothing, and the cost of the second shader would be
// two files to keep in step with one table, which this codebase has argued
// against every other time it came up.
uniform float coat : hint_range(0.0, 1.0) = 0.0;
uniform float coat_rough : hint_range(0.0, 1.0) = 0.1;

// The surface SLIDING over the geometry, in UV units a second.
//
// It is here for `Pulp_Pour`, the pulper's discharge, and it is the one thing
// on this shader that moves. A tongue of cream leaving a chute is the only
// surface in this yard whose SHAPE is allowed to stand still while what is
// drawn on it must not: `pulper.py`'s `flow_mesh` lays a fixed rope of rings
// from the bore to the heap, so there is no silhouette to animate and nothing
// to simulate. Scrolling the albedo, the normal and the roughness together
// along the rope is what turns a frozen blob into something running, and it
// costs one add.
//
// V IS THE AXIS THAT RUNS DOWN THE FLOW, measured off the exported mesh rather
// than assumed: on `Pulp_Pour` the V coordinate correlates -0.91 with world Y
// and +0.91 with world Z, which is the fall turning over and running
// downstream. SUBTRACTING moves the pattern that way, because sampling further
// back up the rope each frame carries what was there forward.
//
// Zero by default, which is every other surface in the yard. The argument for
// carrying it here rather than in a second shader is `coat`'s argument above,
// word for word.
//
// PER MACHINE ON THE POUR, and only there. Every pulper wears its model's one
// copy of the cream, so one pulper pouring cannot scroll it on the material.
// `HayCompressor.flowing_shader` compiles this file again with the define set
// and the pour alone wears that copy, because an instance uniform here would
// give every surface in the yard wearing this shader a slot in the global
// instance buffer, and there are thousands of them.
#ifdef FLOW_PER_INSTANCE
instance uniform vec2 flow_uv : instance_index(4) = vec2(0.0);
#else
uniform vec2 flow_uv = vec2(0.0);
#endif

// Everything above this WORLD height is thrown away.
//
// Only the needle cabinet's ending panel uses it. That panel is the height of
// the case opening and slides down into it, so for the length of the drop the
// part that has not arrived yet would otherwise hang in the air above the
// cornice -- a wooden slab floating over the furniture, which reads as the
// model being broken rather than as a shutter coming down.
//
// A world-space plane rather than a model-space one, so it stays horizontal
// whatever yaw the cabinet was placed at. The default is far above anything in
// this game, so every other surface using this shader is untouched and pays
// only one compare.
uniform float clip_above = 1000.0;

// THE SLAB SLOSHING IN THE HAND: local-space displacement in metres.
//
// It is here for `hay_pulp.glb`, the same one object `coat` above is here for,
// and for the same reason: a wet block that stays rigid while it is carried
// reads as a paving slab. `HayPulp` runs a damped spring per axis, drives it
// off the hand's acceleration, and writes the result here; the vertex stage
// only leans the mesh over by what the spring already decided, so the shape and
// the sound and the weight all agree about one number.
//
// WHAT IT COSTS EVERYTHING ELSE, since this shader skins most of the yard: one
// compare per vertex. The branch below is on a uniform, so every vertex of a
// draw takes the same side of it, and the sin and the normal fix are paid only
// by the slab that is actually moving. A slab standing on the floor writes
// zero here and pays the compare like the stand does.
//
// `wobble_height` is the distance from the anchor plane up to the top of the
// block, because the weight below is a fraction of it. The model puts its
// origin at the centre of its base, so at rest that plane is the floor and the
// foot of the slab stays planted while the top leans.
uniform vec3 wobble = vec3(0.0);
uniform float wobble_phase = 0.0;
uniform float wobble_height = 1.0;

// How tight the ripple across the face is, in radians per metre. The slab is
// about half a metre across, so this puts a little over one wave on it: enough
// that two opposite corners are never in step, and not so much that the surface
// reads as boiling.
const float WOBBLE_RIPPLE = 9.0;
// How much of the lean the ripple is allowed to be. The rest is the whole block
// leaning together, which is what stops it looking like cloth.
const float WOBBLE_RIPPLE_MIX = 0.35;
// Sideways slosh flattens the block. Not conservation of volume, which this is
// nowhere near, but the eye does expect a shape that spreads as it drops.
const float WOBBLE_SQUASH = 0.5;

void vertex() {
	// A `return` is not allowed in a processor function, so the whole stage
	// sits inside the test rather than stepping over it. Same branch either
	// way: one compare on a uniform, taken the same way by every vertex of
	// the draw.
	if (wobble.x != 0.0 || wobble.y != 0.0 || wobble.z != 0.0) {
		// Zero at the anchor plane and one at the top, squared: a linear weight
		// shears the block like a deck of cards, and the square is what makes the
		// top overshoot and the foot hold still.
		float h = max(wobble_height, 0.001);
		float t = clamp(VERTEX.y / h, 0.0, 1.0);
		float w = t * t;
		// Zero outside the band, because the weight is clamped there and a
		// constant does not tilt: without this the lighting on anything above the
		// top of the block leans while the block itself does not.
		float dw = (t > 0.0 && t < 1.0) ? 2.0 * t / h : 0.0;
		float ph = wobble_phase + (VERTEX.x + VERTEX.z) * WOBBLE_RIPPLE;
		float r = sin(ph);
		float dr = cos(ph) * WOBBLE_RIPPLE;
		float lean = 1.0 + WOBBLE_RIPPLE_MIX * r;
		// `flat` is a reserved word in this shading language, hence the name.
		float sag = WOBBLE_SQUASH * length(wobble.xz);

		vec3 d = vec3(wobble.x * w * lean,
			(wobble.y * lean - sag) * w,
			wobble.z * w * lean);
		VERTEX += d;

		// The normal has to come with it, and on this object more than on any
		// other: the slab is the only surface in the game wearing a clearcoat, so
		// what the player actually reads the wobble off is the highlight sliding
		// over it. Displacing the vertices alone leaves that highlight pinned to a
		// shape that is no longer there.
		//
		// First order, N' = N - transpose(J) * N, with J the derivative of the
		// displacement above. Written out rather than sampled twice, because the
		// displacement is an expression and its derivative is nine multiplies.
		float dxx = wobble.x * w * WOBBLE_RIPPLE_MIX * dr;
		float dxy = wobble.x * dw * lean;
		float dzz = wobble.z * w * WOBBLE_RIPPLE_MIX * dr;
		float dzy = wobble.z * dw * lean;
		float dyx = wobble.y * WOBBLE_RIPPLE_MIX * dr * w;
		float dyy = (wobble.y * lean - sag) * dw;
		// The x and z rows are the same expression on purpose: the ripple runs on
		// x + z, so every derivative with respect to x is the derivative with
		// respect to z.
		vec3 jn = vec3(
			NORMAL.x * dxx + NORMAL.y * dyx + NORMAL.z * dzz,
			NORMAL.x * dxy + NORMAL.y * dyy + NORMAL.z * dzy,
			NORMAL.x * dxx + NORMAL.y * dyx + NORMAL.z * dzz);
		NORMAL = normalize(NORMAL - jn);
	}
}

void fragment() {
	if ((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y > clip_above) {
		discard;
	}
	vec2 uv = UV * per_metre + flow_uv * TIME;

	vec3 c = texture(tex_albedo, uv).rgb;
	// Rec. 709 luminance, so desaturating a straw scan does not turn it green.
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(lum), c, saturation);
	if (ao_strength > 0.0) {
		c *= mix(1.0, texture(tex_ao, uv).r, ao_strength);
	}
	// The tint is a gain, so it is applied last and is allowed above 1.0.
	ALBEDO = c * tint;

	NORMAL_MAP = texture(tex_normal, uv).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = mix(rough_min, rough_max, texture(tex_rough, uv).r);
	METALLIC = metallic_amount;
	// Dry by default: see the note on `coat` above. Only the pulp sets it.
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = coat_rough;
	SPECULAR = 0.4;
}

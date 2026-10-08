shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// Loose hay strands, drawn by MultiMesh (both the pile crust and the live
// rigid-body strands). Per-instance tint arrives in COLOR.
//
// The scoop highlight is done here rather than by recolouring instances on the
// CPU: a scoop covers dozens of strands spread across several chunks, and
// rewriting their colours would mean remembering and restoring every one. A
// world-space sphere test costs nothing and needs no state to unwind.
//
// COLOR's alpha is not opacity here, it is "a click could take this". Straw a
// tool is already holding comes through at zero and is left out of the
// highlight; see LiveStrandManager._push_to_multimesh, which is what writes it.

uniform vec3 highlight_center = vec3(0.0);
uniform float highlight_radius = 0.0;          // 0 disables the highlight
uniform vec3 highlight_tint : source_color = vec3(1.0, 0.94, 0.62);
uniform float highlight_mix : hint_range(0.0, 1.0) = 0.7;

// Straw is glossy -- a waxy cuticle, not chalk. These strands are the outermost
// layer of the pile and the only part of it lit directly, so they are where the
// sparkle in assets/reference/ actually comes from: 2.9% of the reference's
// pixels are above 0.75 luminance and almost none of them are bright ALBEDO,
// they are specular hits. At ROUGHNESS 0.64 / SPECULAR 0.16 this material had
// none, which is most of why the pile read as a brown mat.
//
// Kept ROUGH, though. Everything reaching these strands is sky, and straw is
// all grazing angles, so a smooth dielectric here does not glint -- it mirrors
// the whole dome and the pile comes out silver. First pass at 0.26/0.6/0.7
// measured saturation down from 0.53 to 0.30 against a reference at 0.76.
uniform float gloss_rough_lo = 0.54;
uniform float gloss_rough_hi = 0.86;
uniform float gloss_specular = 0.28;
// Along the strand's long axis, which is local Z. StrandFactory.strand_mesh
// writes the tangent array for exactly this.
uniform float anisotropy = 0.20;

varying vec3 v_world;
varying vec4 v_tint;
varying float v_grain;                         // per-strand random, for gloss

// TURNED TO FACE YOU, ABOUT THE STRAND'S OWN AXIS.
//
// StrandFactory.strand_mesh is one flat quad lying in the local XZ plane with
// its length on Z. Every frame it is spun about that Z axis until its face is
// toward the camera, which is what lets a strand be two triangles instead of
// four: the reason the mesh used to be two crossed ribbons was that a single
// ribbon vanishes edge on, and a billboard cannot go edge on.
//
// Nothing is faked by doing it. A strand is an eight millimetre stick, so its
// silhouette is the same rectangle whichever way it is turned, and the axis it
// turns about is the strand's own, so straw still lies the way it was scattered.
//
// The projection is two dot products because random_strand_basis builds the X
// and Y columns orthonormal and scales Z alone for length. So the cross-section
// plane IS the local XY plane, and the view direction lands in it without an
// inverse, a normalise of the matrix, or any assumption about the scale on Z.
uniform float round_face : hint_range(0.0, 1.0) = 0.55;
// HOW MUCH OF THE STRAND'S OWN LIE IT KEEPS, and the whole reason the pile did
// not go pale when it started billboarding.
//
// Turning the geometry to face you is invisible. Turning the SHADING to face
// you is not: every strand then takes its light from the same direction, the
// tonal spread across the crust collapses, and a close shot of the rim comes
// out creamy and flat where it used to have dark straw lying among the lit.
// Rolling the fake cylinder harder does not bring it back, measured: at 0.85
// the edges take MORE sky than they lose sun, and the rim went paler still.
//
// So the normal keeps the direction the strand was scattered facing, which is
// its own local Y, flipped to whichever side the camera is on so a strand can
// be dim but never black. That is exactly the normal one of the old crossed
// ribbons carried, which is why the tone comes back with it.
uniform float own_facing : hint_range(0.0, 1.0) = 0.65;

// THE RIM OF THE DETAIL RING, and nothing else. HayDetail scatters a fixed
// pool of extra strands in a ring round the player and moves the ring as they
// walk, so a strand at the ring's edge has to leave without popping. Past
// `fade_inner` the strand's WIDTH goes to nothing by `fade_outer`, and a quad
// with no width raises no fragments: no discard, no alpha, no per pixel cost.
// `fade_outer` at zero switches the whole thing off, which is what the crust
// and the live strands run at, so this costs them one uniform compare per
// vertex and changes nothing they draw.
uniform vec3 fade_center = vec3(0.0);
uniform float fade_inner = 0.0;
uniform float fade_outer = 0.0;

void vertex() {
	vec3 org = MODEL_MATRIX[3].xyz;
	vec3 to_eye = CAMERA_POSITION_WORLD - org;
	vec2 in_plane = vec2(dot(to_eye, MODEL_MATRIX[0].xyz),
			dot(to_eye, MODEL_MATRIX[1].xyz));
	float d = length(in_plane);
	// Looking straight down the stalk. Any facing will do: there is no
	// silhouette to get wrong from that angle.
	vec2 face = d > 1e-6 ? in_plane / d : vec2(0.0, 1.0);
	vec2 side = vec2(-face.y, face.x);
	float half_w = VERTEX.x;                     // -t or +t, the two long edges
	if (fade_outer > 0.0) {
		half_w *= 1.0 - smoothstep(fade_inner, fade_outer, distance(org, fade_center));
	}
	// A rigid spin of the cross-section about the long axis, rather than
	// `side * VERTEX.x`, which is the same thing for a mesh that is flat in Y
	// and nonsense for one that is not. The probes swap other meshes onto this
	// material to time them, and dropping their Y would be timing a shape they
	// are not drawing.
	VERTEX = vec3(side * half_w + face * VERTEX.y, VERTEX.z);
	// A cylinder, faked across four vertices. The edges roll away from the
	// viewer and the middle interpolates back to facing it, which is what keeps
	// a billboard from reading as a flat chip of straw. At 0 it is a flat card
	// square to the camera; at 1 the middle has no facing left to interpolate
	// to and the stalk goes dark down its centre line.
	vec3 cyl = vec3(face * (1.0 - round_face) + side * (sign(half_w) * round_face), 0.0);
	vec3 own = vec3(0.0, in_plane.y >= 0.0 ? 1.0 : -1.0, 0.0);
	NORMAL = normalize(mix(cyl, own, own_facing));
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_tint = COLOR;
	// Off the instance's own origin, so every fragment of one strand agrees and
	// no two neighbouring strands do. There is no per-instance custom data on
	// the crust MultiMesh and adding a channel to it would cost a float per
	// strand across a million of them; a hash of a value already in hand is free.
	v_grain = fract(sin(dot(org, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void fragment() {
	NORMAL = normalize(NORMAL) * (FRONT_FACING ? 1.0 : -1.0);
	ALBEDO = v_tint.rgb;
	ROUGHNESS = mix(gloss_rough_lo, gloss_rough_hi, v_grain);
	SPECULAR = gloss_specular;
	ANISOTROPY = anisotropy;
	ANISOTROPY_FLOW = vec2(1.0, 0.0);
	// Straw is thin enough that a little light bleeds through from behind.
	BACKLIGHT = vec3(0.15, 0.09, 0.03);

	// THE LOAD ON THE TOOL IS NOT PART OF THE PATCH.
	//
	// The sphere does not have to be aimed AT the load to swallow it. Aimed at
	// spillage the radius is multiplied by Shovel.GATHER_REACH, which is 0.4 m
	// on a fork, and a forkful rides about 1.1 m from the eye a few degrees
	// under the crosshair. Point at anything close (a belt, a container, the
	// floor at your feet) and the aim point comes within that radius of the
	// tines, so the straw the player was carrying lit up along with the target.
	//
	// Skipping it is not just cosmetic, it is the honest answer: Shovel.gather_at
	// passes over anything a tool already holds, so a lit forkful was the
	// highlight promising a pickup that the click would refuse.
	if (highlight_radius > 0.0 && v_tint.a > 0.5) {
		float d = distance(v_world, highlight_center);
		if (d < highlight_radius) {
			// Brighter toward the middle of the scoop, so the shape of what you
			// are about to take is readable rather than a flat disc.
			float f = 1.0 - smoothstep(highlight_radius * 0.55, highlight_radius, d);
			ALBEDO = mix(ALBEDO, highlight_tint, highlight_mix * f);
		}
	}
}

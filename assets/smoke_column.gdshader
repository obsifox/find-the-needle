shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled,
        specular_disabled, unshaded;
// Smoke Shader by Yui Kinomoto (@arlez80), MIT -- https://godotshaders.com/shader/smoke-shader/
// Ported from Godot 3 to 4: hint_color -> source_color, WORLD_MATRIX ->
// MODEL_MATRIX, NORMALMAP -> NORMAL_MAP, and unshaded because this yard's sun
// is low and a lit smoke column went black on the shaded side of the stack.
//
// It wants a MESH, not particles: the fade is on the surface itself, so there
// are no card edges to catch. Billboarded quads gave pale rectangles sliding
// over one another with their corners showing against the shed roof.
//
// WHY THE FADE IS OFF THE VIEW ANGLE AND NOT OFF UV.x
// ---------------------------------------------------
// The original thins the smoke with `sin(UV.x * PI)`, which is right for a QUAD
// -- UV.x runs across the visible width, so the sheet fades at both of its
// edges. Wrapped onto a cylinder that same UV.x runs around the CIRCUMFERENCE,
// so the thin part is pinned to the mesh's seam and the thick part to the strip
// opposite it. Neither has anything to do with where the column's silhouette is
// from the camera, so from most angles the player is looking at a hard-edged
// tube with a bright stripe down it -- the "tunnel".
//
// `dot(NORMAL, VIEW)` is the same fade done in the right frame: one where the
// wall faces the camera, zero where it turns away at the silhouette, from every
// angle. That is also, physically, how much smoke the eye is looking through,
// so the column reads as a body of smoke rather than as a painted surface.
//
// Back faces are culled and depth is never written for the same reason: with
// the far wall drawn too, the two silhouettes cross and the seam between them
// is the edge that reads as the mouth of a pipe.

// How many noise cells the column is cut into: it multiplies the position the
// noise is sampled at, so BIGGER is finer. The original's 1.0 is sized for
// something the size of a room -- on a plume a metre wide it puts barely one
// cell across the whole mesh, which is a flat sheet with a soft blotch on it and
// no smoke in it at all. It has to be several before there is structure to see.
uniform float scale = 1.0;
uniform vec3 tex_speed = vec3(0.0, -2.2, 0.5);
uniform float smoke_volume : hint_range(0.0, 2.0) = 0.8;
// `smoke_volume` again, per MACHINE: a generator's steam comes up with its own
// fire, while every generator wears its own copy of this material (see
// HayCompressor.drive_instance). One on everything that does not set it, which
// is the fire and the stand.
//
// MOBILE FIX (Mali crash at the selling stand): this used to be an
// `instance uniform`, and the stand's puff is the first mesh in the whole load
// that compiles one -- on mobile Vulkan drivers the pipeline died there and
// took the game down at 71-74%. Instance uniforms are gone from every project
// shader now; per-machine variation rides on per-machine material copies.
uniform float volume_gain = 1.0;
// How far in from the silhouette the column starts thinning. One is the bare
// view angle, which only softens the last few degrees and leaves the mesh's own
// outline plainly readable as a cone. Above one the thin band widens and the
// noise gets to eat the edge instead.
uniform float edge_falloff : hint_range(0.5, 4.0) = 1.8;
// How much of the noise counts as smoke: the level the noise has to clear
// before anything is drawn. Lower is thicker.
uniform float smoke_aperture : hint_range(0.0, 1.0) = 0.42;
// How wide the band is between "nothing" and "full". The original multiplied
// the thresholded noise by 75, which is a step edge -- it clipped the plume
// into hard blotches with cut edges, and hard edges are what made the mesh's
// own shape readable.
uniform float smoke_softness : hint_range(0.01, 1.0) = 0.34;
// Stretches the noise away from its own average before anything is done with
// it. A seven-octave fractal sum piles up around 0.5 -- most of the mesh comes
// back between 0.35 and 0.65 -- and a field that flat cannot cut a ragged edge
// whatever it is thresholded at. Two-ish opens it out to nearly the full range.
uniform float noise_contrast : hint_range(1.0, 6.0) = 2.2;
// How far the sample point wanders sideways as it climbs, in noise units per
// unit of height. A plume that rises dead straight reads as a shape being
// rendered rather than as air moving.
uniform float sway : hint_range(0.0, 2.0) = 0.55;
// How far a second, coarser noise drags the sample point around before the
// first one is read. Value noise is built on an axis-aligned integer lattice,
// and a sharp threshold through it cuts along those axes -- straight vertical
// and horizontal edges, which read as torn paper rather than as smoke. Warping
// the domain first means the contour crosses the lattice at every angle, and it
// is the difference between two fractal samples and nine.
uniform float warp : hint_range(0.0, 3.0) = 1.2;
uniform vec4 smoke_color : source_color = vec4(0.185, 0.185, 0.185, 1.0);
// Fades the whole column out at its top so it dissipates instead of ending.
uniform float top_fade : hint_range(0.0, 1.0) = 0.55;
// ...and at its bottom, so it grows out of the stack mouth instead of starting
// at full width on the rim.
uniform float base_fade : hint_range(0.0, 1.0) = 0.18;

varying vec4 world_vertex;

float random(vec3 pos) {
        return fract(sin(dot(pos, vec3(12.9898, 78.233, -3.532532))) * 43758.5453);
}

float value_noise(vec3 pos) {
        vec3 p = floor(pos);
        vec3 f = fract(pos);
        float v000 = random(p);
        float v100 = random(p + vec3(1.0, 0.0, 0.0));
        float v010 = random(p + vec3(0.0, 1.0, 0.0));
        float v110 = random(p + vec3(1.0, 1.0, 0.0));
        float v001 = random(p + vec3(0.0, 0.0, 1.0));
        float v101 = random(p + vec3(1.0, 0.0, 1.0));
        float v011 = random(p + vec3(0.0, 1.0, 1.0));
        float v111 = random(p + vec3(1.0, 1.0, 1.0));
        vec3 u = f * f * (3.0 - 2.0 * f);
        return mix(
                mix(mix(v000, v100, u.x), mix(v010, v110, u.x), u.y),
                mix(mix(v001, v101, u.x), mix(v011, v111, u.x), u.y),
                u.z);
}

float noise_tex(vec3 p) {
        return value_noise(p * 0.984864) * 0.5
                + value_noise(p * 2.543) * 0.25
                + value_noise(p * 9.543543) * 0.125
                + value_noise(p * 21.65436) * 0.0625
                + value_noise(p * 42.0) * 0.03125
                + value_noise(p * 87.135148) * 0.015625
                + value_noise(p * 340.66534654) * 0.0078125;
}

void vertex() {
        world_vertex = MODEL_MATRIX * vec4(VERTEX * scale, 1.0);
}

void fragment() {
        // ONE sample, where the original took nine.
        //
        // The other eight were a 3x3 tap the original ran a Sobel filter over to
        // derive a NORMAL_MAP -- and this material is `unshaded`, so nothing is ever
        // lit by that normal and the whole result was thrown away. Each tap is a
        // seven-octave fractal, so the plume was costing sixty-three value_noise
        // evaluations per pixel to compute a value it did not use.
        float height = clamp(UV.y, 0.0, 1.0);

        // The sample point drifts sideways as it climbs, so the pattern the plume is
        // cut from meanders instead of standing straight up over the pipe.
        vec3 at = world_vertex.xyz + tex_speed * TIME;
        at.xz += vec2(sin(height * 2.1 + TIME * 0.31),
                cos(height * 1.7 + TIME * 0.23)) * sway * height;
        // ONE sample, where the original took nine.
        //
        // The other eight were a 3x3 tap the original ran a Sobel filter over to
        // derive a NORMAL_MAP -- and this material is `unshaded`, so nothing is ever
        // lit by that normal and the whole result was thrown away. Each tap is a
        // seven-octave fractal, so the plume was costing sixty-three value_noise
        // evaluations per pixel to compute a value it did not use.
        // Warped first: see `warp`. The offsets are arbitrary and only there to stop
        // the two samples sharing a lattice.
        float drag = noise_tex(at * 0.41 + vec3(19.3, 7.1, 4.7)) - 0.5;
        at += vec3(drag, drag * 0.6, -drag) * warp;
        float density = clamp((noise_tex(at) - 0.5) * noise_contrast + 0.5, 0.0, 1.0);

        // How much column the eye is looking through here: one straight on, zero at
        // the silhouette, whatever direction the camera comes from. abs() because
        // the plume is thin enough to see the far wall through and its normal points
        // the other way.
        float depth_through = abs(dot(normalize(NORMAL), normalize(VIEW)));
        // The original ends the column with a hard edge at both ends of the mesh. A
        // chimney's plume grows out of the mouth and thins away at the top, so both
        // ends are faded rather than cut.
        float rise = smoothstep(0.0, max(base_fade, 0.001), height);
        float dissipate = 1.0 - smoothstep(1.0 - top_fade, 1.0, height);
        // Everything about the CONE, in one number: thick down the middle, gone at
        // the silhouette, growing out of the mouth and thinning away at the top.
        float shape = clamp(pow(depth_through, edge_falloff) * smoke_volume * volume_gain, 0.0, 1.0)
                * rise * dissipate;

        // THE NOISE DECIDES WHERE THE EDGE IS, NOT HOW BRIGHT IT IS.
        //
        // This is the whole difference between smoke and a cone with a soft rim.
        // Fading the cone out and then multiplying noise over it leaves the outline
        // exactly where the mesh put it: every contour of the result is a contour of
        // the cone, so however soft the fade is, the eye still reads a cone -- which
        // is what the player kept seeing and calling a tunnel.
        //
        // Multiplying the noise IN before the threshold moves the boundary instead.
        // The plume ends where `density * shape` falls below the gate, and since
        // density is a moving fractal, that contour is ragged, has tongues sticking
        // out where the noise runs high and bites taken out of it where it runs low.
        // The mesh stops being a shape that is drawn and becomes the envelope the
        // smoke is cut out of, which is why the cone is now wider than the plume.
        float gate = smoke_aperture + (1.0 - smoke_aperture) * height * 0.35;
        float smoke = smoothstep(gate, gate + smoke_softness, density * shape);

        ALBEDO = smoke_color.rgb;
        ALPHA = clamp(smoke * smoke_color.a, 0.0, 1.0);
}

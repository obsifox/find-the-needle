shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Light along a unit cylinder: the satellite dish's uplink and downlink, and the
// beams and circles it leaves standing on the pile. The mesh is a CylinderMesh of
// height 1 and radius 1, stretched per use by the instance's own scale (see
// NeedleRadar._stretch), so one mesh serves every beam in the yard.
//
// A tube lit evenly reads as a pipe. This one is brightest where it faces the
// camera and falls away to nothing at its silhouette, which is what a shaft of
// light in haze looks like. `rim` turns that inside out for a wide circle, whose
// wall should glow at its edges and stay clear in front of the hay it is marking.
//
// Pulses run from the bottom of the mesh to its top, and the dish always
// stretches a beam from where the light starts to where it lands: horn to sky,
// sky to pile, needle to air. Distances are in metres rather than in UV, read off
// the stretch, so a pulse is the same size on a 4 m mark and on an 80 m uplink.

uniform vec3 tint : source_color = vec3(0.45, 0.9, 1.0);
/// The colour the middle of the shaft burns towards.
uniform vec3 core_tint : source_color = vec3(0.92, 1.0, 1.0);
uniform float intensity = 1.0;
/// 0 for a shaft, 1 for a wall of light round a circle.
uniform float rim : hint_range(0.0, 1.0) = 0.0;
/// Metres between pulses, and metres a second they travel.
uniform float pulse_spacing = 3.0;
uniform float pulse_speed = 12.0;
uniform float pulse_amount = 0.8;
/// Metres over which each end fades in, so neither end is a hard cut.
uniform float end_fade = 0.6;
/// 1 fades the light out going up the mesh, for a wall rising out of the hay.
uniform float top_fade : hint_range(0.0, 1.0) = 0.0;
/// Per mark, so every mark can fade on its own clock and still share
/// this one material family (driven per mesh through its own material copy).
uniform float fade = 1.0;

varying float along_m;
varying float length_m;

void vertex() {
        length_m = length(MODEL_MATRIX[1].xyz);
        along_m = (VERTEX.y + 0.5) * length_m;
}

float hash(float n) {
        return fract(sin(n) * 43758.5453);
}

float noise1(float x) {
        float i = floor(x);
        float f = fract(x);
        f = f * f * (3.0 - 2.0 * f);
        return mix(hash(i), hash(i + 1.0), f);
}

void fragment() {
        float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
        float core = pow(facing, 7.0);
        float body = pow(facing, 1.6);
        float shaft = body * 0.5 + core * 1.1;
        float wall = pow(1.0 - facing, 2.5) * 0.9 + 0.08;
        float shape = mix(shaft, wall, rim);

        float phase = along_m - TIME * pulse_speed;
        float pulse = pow(0.5 + 0.5 * sin(phase * TAU / pulse_spacing), 10.0) * pulse_amount;
        float flicker = 0.82 + 0.3 * noise1(along_m * 1.3 - TIME * 7.0 + UV.x * 5.0);

        float ends = smoothstep(0.0, end_fade, along_m)
                * smoothstep(0.0, end_fade, length_m - along_m);
        float rise = along_m / max(length_m, 0.001);
        float up = mix(1.0, pow(1.0 - clamp(rise, 0.0, 1.0), 1.5), top_fade);

        vec3 col = mix(tint, core_tint, clamp(core * (1.0 - rim) + pulse * 0.35, 0.0, 1.0));
        ALBEDO = col * shape * (flicker + pulse) * ends * up * intensity * fade;
}

shader_type spatial;
// Material that is only drawn where it has actually got to.
//
// `BriquettePress` is the machine this was written for. Its streams of hay and
// pellets are baked bands that loop on a clip, and switching a whole band on
// when its mill starts made a metre of pellets appear on the belt in one frame.
// This draws the same band, but only between a TAIL and a FRONT measured along
// the road the material travels, so a stream visibly pours out of its source
// and runs into the die, and when the source stops it drains in after it.
//
// The road is a straight line per mesh, given in WORLD space and not in the
// mesh's own, because the band slides along its own length under the clip and
// a distance taken in mesh space would slide with it. `road_offset` is how far
// down the whole road this mesh's line starts, so a road that bends (the hay's
// L, the pellets' fall into the spout and onto the belt) is several meshes each
// carrying its own piece of one distance.
//
// Two segments and not one, because a side that stops and starts again inside a
// few seconds has the end of the last pour still draining into the die while
// the start of the next is coming out of the spout.
//
// The flats the model imported with, copied in, and double sided, because every
// straw and pellet material on the press is.
render_mode cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
// The edge is broken up rather than sawn: a hard line across a mat of straw
// reads as a wiper, not as the front of a pour. Cells about a pellet and a half
// across, pushed up to this far either side of the true front.
uniform float edge_cell = 0.035;
uniform float edge_jitter = 0.06;

uniform vec3 road_origin = vec3(0.0);
uniform vec3 road_dir = vec3(0.0, 0.0, 1.0);
uniform float road_offset = 0.0;
// (tail, front) in metres down the road. The defaults draw nothing.
uniform vec2 road_seg_a = vec3(1000.0, -1000.0).xy;
uniform vec2 road_seg_b = vec3(1000.0, -1000.0).xy;

varying vec3 from_origin;

void vertex() {
        from_origin = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - road_origin;
}

float cell_noise(vec3 p) {
        return fract(sin(dot(floor(p / edge_cell), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
        float s = road_offset + dot(from_origin, road_dir)
                + (cell_noise(from_origin) * 2.0 - 1.0) * edge_jitter;
        bool in_a = s > road_seg_a.x && s < road_seg_a.y;
        bool in_b = s > road_seg_b.x && s < road_seg_b.y;
        if (!in_a && !in_b) {
                discard;
        }
        ALBEDO = albedo.rgb;
        ROUGHNESS = roughness;
        METALLIC = metallic;
        SPECULAR = specular;
}

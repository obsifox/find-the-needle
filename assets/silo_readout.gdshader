shader_type spatial;
render_mode cull_back, shadows_disabled;

// The three digit seven-segment display on a hay silo's console door.
//
// WHY A SHADER AND NOT GEOMETRY THE GAME TURNS ON AND OFF
// ------------------------------------------------------
// `silo.py` models every segment as its own slab and gives it either the lit
// amber material or the display's dark plastic, so which number the display
// shows is decided in Blender and baked: the whole cabinet, all twenty one
// segments of it, arrives as ONE joined mesh with two materials on it. There is
// no node to turn on. Making one would mean twenty one extra objects on every
// silo in the yard, exported, imported and walked, so that three digits can
// change.
//
// This draws the same twenty one slabs in the same places instead, on a single
// quad the game stands a millimetre in front of the display glass. The modelled
// bezel, recess and lens still frame it, so what changes is only what is written
// on the screen. `HaySilo._build_readout` measures the quad off the same numbers
// silo.py builds the window from, and hands the segment proportions in as
// uniforms rather than repeating them here, so the drawing and the model cannot
// drift.
//
// NOT `unshaded`, deliberately. The window is on a door standing in a yard, and
// an unlit segment is dark PLASTIC rather than a hole: it has to take the sun
// and the shed's gloom the way the slabs beside it do. Only the lit ones glow,
// which is exactly what the modelled pair of materials does.
//
// THE COLOURS CARRY NO `source_color` HINT. They are handed in raw from
// `hay_silo_materials.json`, which is the same table `HayCompressor.make_material`
// pours straight into a StandardMaterial3D's `albedo_color`. Tagging them here
// would put an sRGB conversion on one of those two paths and not the other, and
// the overlay would be a visibly different amber from the segments modelled on
// the gauges a hand's width above it.

// The number on the screen, right aligned, leading zeros blanked. Over 999 is
// clamped rather than wrapped: a display that shows 012 for 1012 is worse than
// one that sticks at its top.
//
// PER SILO, ON THE PANE AND NOT THE MATERIAL. Every silo wears one copy of this
// material (see HayCompressor.shared_material), because a copy per silo is a
// mesh and material pair nothing else shares and cannot be drawn instanced. The
// number is the one thing that differs between two silos, so it lives on the
// per-machine; `HaySilo._apply_readout` sets it through
// HayCompressor.drive_instance. Everything below it is a constant.
uniform int value = 0;
// How many digit cells the quad is divided into.
uniform float cells = 3.0;
// What fraction of a cell the glyph itself covers, across and up. The rest is
// the gap silo.py leaves between digits and the clearance above and below.
uniform vec2 glyph = vec2(0.675, 0.769);
// A segment's thickness, and its length, in the glyph's own box: 1.0 across is
// the glyph's width and 1.0 up is its height. Readings of silo.py's `readout`.
uniform float bar_thick = 0.11;
uniform float bar_len = 0.86;
uniform float post_thick = 0.196;
uniform float post_len = 0.44;

uniform vec3 on_color = vec3(0.52, 0.30, 0.02);
uniform vec3 off_color = vec3(0.030, 0.030, 0.035);
uniform float on_emit = 0.55;
uniform float on_rough = 0.24;
uniform float off_rough = 0.18;

// Which of the seven segments each numeral lights, as bits a..g = 1..64. The
// same table as silo.py's SEG_ON, and written out for its reason: a readout with
// the wrong pattern on it is a machine with a typo on its face.
const int GLYPH_MASK[10] = {63, 6, 91, 79, 102, 109, 125, 7, 127, 111};

// Signed distance to a box, negative inside. One function for all seven, so a
// segment is a position and a size and nothing else.
float box_sd(vec2 p, vec2 half_size) {
        vec2 d = abs(p) - half_size;
        return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

// How much of this pixel the segment covers, softened by one pixel so a slab
// edge is a line rather than a staircase.
float seg_cover(int mask, int bit, vec2 g, vec2 at, vec2 half_size, float aa) {
        if ((mask / bit) % 2 == 0) {
                return 0.0;
        }
        return 1.0 - smoothstep(-aa, aa, box_sd(g - at, half_size));
}

void fragment() {
        int shown = clamp(value, 0, 999);
        int n = int(cells);
        float u = UV.x * cells;
        int cell = clamp(int(floor(u)), 0, n - 1);

        // The place this cell stands in, worked out by dividing down rather than by
        // a power: shader `pow` is a float, and 10^2 coming back as 99.999 is a
        // hundreds digit that reads one too low on some machines and not others.
        int place = 1;
        for (int i = cell + 1; i < n; i++) {
                place *= 10;
        }
        // A leading zero is BLANK and not "0". A drive display reading 010 for ten
        // a minute is a display nobody trusts the first digit of.
        bool blanked = (shown < place) && (cell < n - 1);
        int digit = (shown / place) % 10;

        // Into the glyph's own box: one unit wide, one tall, origin in the middle,
        // +y up. UV.y runs down the quad, which is the flip.
        vec2 g = vec2((fract(u) - 0.5) / glyph.x, (0.5 - UV.y) / glyph.y);
        float aa = fwidth(g.x) * 0.8;

        float lit = 0.0;
        if (!blanked) {
                int m = GLYPH_MASK[digit];
                vec2 bar = vec2(bar_len, bar_thick) * 0.5;
                vec2 post = vec2(post_thick, post_len) * 0.5;
                lit = max(lit, seg_cover(m, 1, g, vec2(0.0, 0.5), bar, aa));    // a, top
                lit = max(lit, seg_cover(m, 2, g, vec2(0.5, 0.25), post, aa));  // b
                lit = max(lit, seg_cover(m, 4, g, vec2(0.5, -0.25), post, aa)); // c
                lit = max(lit, seg_cover(m, 8, g, vec2(0.0, -0.5), bar, aa));   // d, foot
                lit = max(lit, seg_cover(m, 16, g, vec2(-0.5, -0.25), post, aa)); // e
                lit = max(lit, seg_cover(m, 32, g, vec2(-0.5, 0.25), post, aa));  // f
                lit = max(lit, seg_cover(m, 64, g, vec2(0.0, 0.0), bar, aa));   // g, bar
        }

        ALBEDO = mix(off_color, on_color, lit);
        EMISSION = on_color * on_emit * lit;
        ROUGHNESS = mix(off_rough, on_rough, lit);
        METALLIC = 0.0;
        SPECULAR = 0.4;
}

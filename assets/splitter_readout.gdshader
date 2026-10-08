shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// The splitter's screen: the machine's own plan, drawn on its own glass, saying
// which of its five settings it is on.
//
// A PLAN AND NOT A WORD. This is read from three metres by a player walking
// past, and at that range a word is a smudge while a shape is still a shape. So
// it draws the wye itself -- stem toward the viewer, two arms fanning away --
// and says the setting by what is lit:
//
//     turn about   both arms half lit          they take it in turns
//     left / right only   one arm lit, the other dark with a bar across it
//     left / right first  one arm lit, the other on standby
//
// The BAR is what separates the two that would otherwise look alike. A pinned
// machine and a main line both light one arm; the difference is whether the
// other arm is shut or merely waiting, and that difference is the whole of what
// the two settings do to the run behind it. A dim arm is open. A barred arm is
// closed. Without the bar the screen would confidently show a player the same
// picture for a branch that is being fed on overflow and a branch that has been
// switched off, which is the one lie this machine must not tell.
//
// ORIENTED FROM THE PLAYER'S SIDE, which is the only side it can be read from.
// The pane faces upstream, so the viewer looks downstream along the hay's own
// travel: the stem at the bottom is the run they are standing on. u increases
// to the viewer's RIGHT and ConveyorSplitter.LEFT is on their left, so the arm
// drawn at low u is LEFT. Mirrored, this would point at the wrong branch with
// total confidence, which is worse than having no screen.

uniform vec3 on_color : source_color = vec3(1.0, 0.64, 0.16);
uniform vec3 off_color : source_color = vec3(0.10, 0.12, 0.14);
uniform vec3 shut_color : source_color = vec3(0.86, 0.19, 0.15);
uniform vec3 ground : source_color = vec3(0.021, 0.026, 0.030);
uniform float on_emit = 2.6;
// ConveyorSplitter.SET_* as a number, because set_shader_parameter has no
// strings: 0 turn about, 1 pin left, 2 pin right, 3 main left, 4 main right.
// Kept in one place -- ConveyorSplitter._screen_mode is the other end of it.
uniform float mode = 0.0;
uniform float aspect = 1.6684;
uniform float bar = 0.070;
// 0 draws the wye, 1 draws a T. ConveyorTSplitter sets the rest of these.
uniform float layout = 0.0;
// The T's three lanes as segments: 0 the stem, 1 the bar end at the model's +X
// (drawn on the viewer's left), 2 the bar end at -X. Which one hay comes IN
// by, and which segments are the load's LEFT and RIGHT arms. A T can be fed
// along its bar, so the arms are not always the two bar ends.
uniform float entry_seg = 0.0;
uniform float left_seg = 1.0;
uniform float right_seg = 2.0;
// A T with two belts arriving merges them. Then both other segments carry an
// arrowhead in, `out_seg` is lit as the way out, and the segment whose turn it
// is (`serving_seg`) is lit full while the other waits dim.
uniform float merge = 0.0;
uniform float out_seg = 0.0;
uniform float serving_seg = 1.0;

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// 1.0 when `mode` is `want`, without an integer compare.
float is_mode(float want) {
	return 1.0 - step(0.5, abs(mode - want));
}

// 1.0 when a segment index is `want`.
float is_seg(float at, float want) {
	return 1.0 - step(0.5, abs(at - want));
}

// The T: a bar across the top of the glass and a stem down to the viewer, the
// way the machine lies when it is fed at its stem. The segment hay comes in by
// is lit whole and carries an arrowhead pointing into the junction, so a T fed
// along its bar reads as one at a glance. The two arms are lit and barred by
// the wye's own rules, only on whichever segments they are.
void draw_t(vec2 p, float fw, float lit_l, float lit_r, float shut_l, float shut_r,
		inout vec3 col, inout float glow) {
	const vec2 JOIN = vec2(0.0, 0.28);
	vec2 ends[3] = vec2[3](vec2(0.0, -0.22), vec2(-0.56, 0.28), vec2(0.56, 0.28));
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float is_out = is_seg(out_seg, fi);
		float split_entry = is_seg(entry_seg, fi);
		float as_left = is_seg(left_seg, fi) * (1.0 - split_entry) * (1.0 - merge);
		float as_right = is_seg(right_seg, fi) * (1.0 - split_entry) * (1.0 - merge);
		float entry = mix(split_entry, 1.0 - is_out, merge);
		float lit_split = max(split_entry, max(as_left * lit_l, as_right * lit_r));
		float lit_merge = max(is_out, mix(0.4, 1.0, is_seg(serving_seg, fi)));
		float lit = mix(lit_split, lit_merge, merge);
		float shut = as_left * shut_l + as_right * shut_r;
		vec2 end = ends[i];
		float m = 1.0 - smoothstep(bar - fw, bar + fw, seg(p, end, JOIN));
		vec2 dir = normalize(JOIN - end);
		vec2 perp = vec2(-dir.y, dir.x);
		// The bar across a shut arm, two thirds of the way out from the join.
		vec2 at = JOIN - dir * 0.34;
		float m_bar = 1.0 - smoothstep(bar * 0.62 - fw, bar * 0.62 + fw,
			seg(p, at - perp * 0.14, at + perp * 0.14));
		// The arrowhead on the feed: two strokes meeting at a point along it,
		// drawn in the ground colour so they read cut into the lit segment.
		vec2 tip = end + dir * 0.30;
		vec2 back = tip - dir * 0.10;
		float m_head = 1.0 - smoothstep(bar * 0.34 - fw, bar * 0.34 + fw,
			min(seg(p, back + perp * 0.09, tip), seg(p, back - perp * 0.09, tip)));
		col = mix(col, mix(off_color, on_color, lit), m);
		col = mix(col, shut_color, m_bar * shut);
		col = mix(col, ground, m_head * m * entry);
		glow += m * lit * (1.0 - m_head * entry) + m_bar * shut;
	}
}

void fragment() {
	// Centred, aspect-corrected, and with v flipped so +y is UP the screen.
	vec2 p = (UV - vec2(0.5)) * vec2(aspect, -1.0);

	// The drawing is LIFTED clear of the bottom fifth of the glass, which is
	// left empty for the caption (see ConveyorSplitter.CAPTION_DY). Nothing here
	// draws the word: a seven-segment cell will make any digit, which is why the
	// silo spells its number out in GLSL, but this shows one of five NAMES and
	// hand-building "TURN ABOUT" out of strokes would be a font written in a
	// shader. So the shape and the word are two things, and this one keeps out
	// of the other's way.
	const vec2 JOIN = vec2(0.0, 0.04);
	const vec2 L_END = vec2(-0.52, 0.40);
	const vec2 R_END = vec2(0.52, 0.40);
	const vec2 STEM = vec2(0.0, -0.16);

	float turn = is_mode(0.0);
	float pin_l = is_mode(1.0);
	float pin_r = is_mode(2.0);
	float main_l = is_mode(3.0);
	float main_r = is_mode(4.0);

	// How lit each arm is, and whether it is barred shut.
	float lit_left = max(turn * 0.5, max(pin_l, main_l));
	float lit_right = max(turn * 0.5, max(pin_r, main_r));
	// A main line's spill arm is on standby: open, waiting, and visibly not the
	// one getting the hay.
	lit_left = max(lit_left, main_r * 0.22);
	lit_right = max(lit_right, main_l * 0.22);
	float shut_left = pin_r;
	float shut_right = pin_l;

	float fw = max(fwidth(p.x), 0.0008);
	float m_stem = 1.0 - smoothstep(bar - fw, bar + fw, seg(p, STEM, JOIN));
	float m_left = 1.0 - smoothstep(bar - fw, bar + fw, seg(p, JOIN, L_END));
	float m_right = 1.0 - smoothstep(bar - fw, bar + fw, seg(p, JOIN, R_END));

	// The bar across a shut arm, struck square across it two thirds of the way
	// out. Drawn at the arm's own angle turned by a right angle, so it reads as
	// a barrier on that branch and not as a stray mark on the glass.
	vec2 l_dir = normalize(L_END - JOIN);
	vec2 r_dir = normalize(R_END - JOIN);
	vec2 l_at = JOIN + l_dir * 0.42;
	vec2 r_at = JOIN + r_dir * 0.42;
	vec2 l_perp = vec2(-l_dir.y, l_dir.x) * 0.14;
	vec2 r_perp = vec2(-r_dir.y, r_dir.x) * 0.14;
	float m_bar_l = 1.0 - smoothstep(bar * 0.62 - fw, bar * 0.62 + fw,
		seg(p, l_at - l_perp, l_at + l_perp));
	float m_bar_r = 1.0 - smoothstep(bar * 0.62 - fw, bar * 0.62 + fw,
		seg(p, r_at - r_perp, r_at + r_perp));

	// The feed is always live: something is arriving whatever the blade decides.
	vec3 col = ground;
	col = mix(col, on_color, m_stem);
	col = mix(col, mix(off_color, on_color, lit_left), m_left);
	col = mix(col, mix(off_color, on_color, lit_right), m_right);
	col = mix(col, shut_color, m_bar_l * shut_left);
	col = mix(col, shut_color, m_bar_r * shut_right);

	// Emission follows the same masks weighted by how lit each is, so a dark arm
	// is genuinely dark rather than dim-but-glowing, and a bar reads as a lamp.
	float glow = m_stem + m_left * lit_left + m_right * lit_right
		+ m_bar_l * shut_left + m_bar_r * shut_right;

	// A T draws its own plan in place of the wye. A fragment function cannot
	// return early, so the wye above is worked out and set aside.
	if (layout > 0.5) {
		col = ground;
		glow = 0.0;
		draw_t(p, fw, lit_left, lit_right, shut_left, shut_right, col, glow);
	}

	ALBEDO = col;
	EMISSION = col * on_emit * clamp(glow, 0.0, 1.0);
	ROUGHNESS = 0.22;
	SPECULAR = 0.4;
	METALLIC = 0.0;
}

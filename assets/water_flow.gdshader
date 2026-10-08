shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// The column of water inside a main's inspection window: the one surface in the
// water kit that moves, and the only thing in a run that says whether there is
// anything in it.
//
// A pipe carries its load on the INSIDE and can never show it, which is the
// whole difficulty assets/blender/_build/water_pipe.py argues its way through.
// The window is the answer, this is what the window is for, and `Pipe_Water` is
// its own mesh precisely so it can be painted with this while the glass around
// it never changes.
//
// WHY IT SCROLLS HERE AND NOT ON THE SHELL. The belt's cleats move because the
// belt moves: they are real objects and assets/conveyor_surface.gdshader only
// draws them where they already are. A pipe's shell stands still, so paint
// crawling along the outside of one is a lie the eye catches in about a second.
// Inside the glass, where the water really is, scrolling is not a trick at all.
//
// UVS ARRIVE IN METRES. `revolve` in water_pipe.py writes cylindrical UVs where
// U is arc length around the barrel and V is distance along the profile, both
// real measurements, so `speed` is literally metres a second and the water in
// the glass travels at the rate the network says it does.
//
// V RUNS THE OTHER WAY FROM THE BELT'S, and the sign below is measured rather
// than reasoned. Blender's -Y is downstream and the glTF conversion maps that
// to Godot +Z while flipping V, so dv/dz comes out at -1.00 on the exported
// column (the belt's carrying strand measures +1.00). Adding TIME therefore
// walks the water toward +Z, which is the direction BeltPath.run_basis drives
// and the direction a main runs. Subtracting runs it backwards up its own pipe.

// The three colours come straight out of assets/models/water_pipe_materials.json,
// where `M_WP_Water` carries `still`, `color` and `foam` beside the numbers the
// .blend renders with. PipeKit reads them from that table, so the render and the
// yard cannot drift apart by somebody editing one of them.
uniform vec3 still : source_color = vec3(0.14, 0.33, 0.40);
uniform vec3 flowing : source_color = vec3(0.34, 0.502, 0.54);
uniform vec3 foam : source_color = vec3(0.64, 0.76, 0.75);
uniform float foam_share : hint_range(0.0, 1.0) = 0.4;

// 0..1. How much of what this network was asked for it is actually delivering,
// which in stage 3 is WaterGrid satisfaction and until then is whatever the run
// was told. It does two things at once and that is deliberate: it is the
// colour, so a starved main is dark and still, and it is the pace, so a
// browned-out main crawls. One number, read two ways, exactly as `power` is on
// every machine that eats electricity.
uniform float flow : hint_range(0.0, 1.0) = 0.0;
// Metres a second at flow = 1. What the water is doing, not what the pipe is.
uniform float speed = 1.6;
uniform float rough = 0.44;

varying vec2 v_uv;

void vertex() {
	// Scrolled in the vertex stage, like the belt's cleats, so the streaks and
	// their shading are guaranteed to be the same water.
	v_uv = UV + vec2(0.0, TIME * speed * flow);
}

void fragment() {
	// Streaks ALONG the run, at two periods that do not divide each other, so
	// the pattern does not visibly repeat over the half metre of glass the
	// player is looking through. Both are fine enough to read as moving water
	// rather than as stripes on a rod.
	float a = sin(v_uv.y * 34.0 + v_uv.x * 7.0);
	float b = sin(v_uv.y * 71.0 - v_uv.x * 11.0);
	// CUBED, and the exponent is doing real work rather than tidying. The plain
	// average of two sines is above half over most of the surface, so the foam
	// was mixed in nearly everywhere and the column came out a pale grey rod
	// with the water's own colour washed out of it. Sharpening it puts the foam
	// where foam is, which is in threads, and leaves the body of the water
	// reading as water.
	float streak = pow(clamp(a * 0.5 + b * 0.5, 0.0, 1.0), 3.0);

	// Foam only where there is something to froth. Still water in a dead main
	// is flat and dark; a main at full flow is the brightest thing in a run,
	// which is what makes the window findable from across the yard.
	vec3 body = mix(still, flowing, flow);
	ALBEDO = mix(body, foam, streak * foam_share * flow);
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	// A little light of its own at full flow, so a live main reads at a
	// distance the way a lit machine does rather than needing the player to
	// walk up to it. Well under world.gd's glow threshold: this is water in a
	// pipe catching the light, not a lamp.
	EMISSION = body * flow * 0.18;
}

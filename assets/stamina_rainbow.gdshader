shader_type canvas_item;

// The stamina bar's fill after an Extra Life Coin: a rainbow running along the
// bar and scrolling, laid over the bar's own colour by `amount` so the glow can
// fade back out. Hud puts this on the fill only while the glow lasts and takes it
// off again, so the bar draws with no shader at all the rest of the time.

uniform float phase = 0.0;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	// A little under one turn of the wheel across the bar, and softened towards
	// white so it reads as light rather than as a warning.
	vec3 rainbow = mix(vec3(1.0), hue(UV.x * 0.85 - phase), 0.70);
	COLOR.rgb = mix(COLOR.rgb, rainbow, amount);
}

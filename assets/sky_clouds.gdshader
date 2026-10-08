shader_type sky;
// Procedural daylight sky with drifting cumulus, matching the open roof slot in
// the reference footage. Cheap enough to leave on at every quality level.

uniform vec3 sky_top : source_color = vec3(0.16, 0.34, 0.72);
uniform vec3 sky_horizon : source_color = vec3(0.60, 0.73, 0.88);
uniform vec3 ground_color : source_color = vec3(0.10, 0.11, 0.14);
uniform vec3 cloud_color : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_shadow : source_color = vec3(0.55, 0.60, 0.70);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.46;
uniform float cloud_speed = 0.0045;
uniform float sun_disk = 0.9993;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += amp * value_noise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float up = dir.y;

	vec3 col = mix(sky_horizon, sky_top, clamp(pow(max(up, 0.0), 0.55), 0.0, 1.0));
	if (up < 0.0) {
		col = mix(sky_horizon, ground_color, clamp(-up * 5.0, 0.0, 1.0));
	}

	if (up > 0.015) {
		// Project the view direction onto a cloud plane overhead.
		vec2 uv = dir.xz / max(up, 0.015) * 0.10;
		uv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.6);
		float f = fbm(uv);
		float density = smoothstep(cloud_cover, cloud_cover + 0.22, f);
		// A second, offset sample gives the puffs a lit top and shaded underside.
		float lit = smoothstep(cloud_cover - 0.02, cloud_cover + 0.30, fbm(uv + vec2(0.06, 0.04)));
		vec3 puff = mix(cloud_shadow, cloud_color, lit);
		float fade = smoothstep(0.015, 0.22, up);
		col = mix(col, puff, density * fade * 0.94);
	}

	if (LIGHT0_ENABLED) {
		float d = dot(dir, LIGHT0_DIRECTION);
		col += LIGHT0_COLOR * LIGHT0_ENERGY * smoothstep(sun_disk, 1.0, d) * 6.0;
		col += LIGHT0_COLOR * pow(max(d, 0.0), 48.0) * 0.35;
	}

	COLOR = col;
}

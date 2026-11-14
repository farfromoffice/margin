shader_type sky;
// Space as seen from low orbit: black sky, stars, a hard Sun disc, and Earth
// filling the lower part with a thin blue limb. Also feeds ambient light and
// reflections, which is what makes the metal and cover glass read as real.

uniform vec3 sun_color : source_color = vec3(1.0, 0.97, 0.9);
// how far below the horizon the Earth's limb sits, in direction y
uniform float limb_y = -0.3;
uniform float spin = 0.0;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
			mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise2(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	vec3 col = vec3(0.0);

	// stars, only where Earth doesn't cover them
	vec3 cell = floor(d * 220.0);
	float h = hash3(cell);
	if (h > 0.9965) {
		col += vec3(0.8, 0.85, 1.0) * (h - 0.9965) * 300.0 * 0.35;
	}

	// Sun: hard disc plus a little bloom
	vec3 L = normalize(LIGHT0_DIRECTION);
	float s = dot(d, L);
	col += sun_color * smoothstep(0.9995, 0.9998, s) * 40.0;
	col += sun_color * pow(max(s, 0.0), 400.0) * 1.5;

	// Earth below the limb: ocean, land, clouds, lit from the Sun side
	float below = limb_y - d.y;
	if (below > 0.0) {
		vec2 q = d.xz / max(-d.y + 0.25, 0.05) * 1.6 + vec2(spin, 0.0);
		float land = smoothstep(0.52, 0.56, fbm(q * 1.3));
		vec3 surface = mix(vec3(0.02, 0.09, 0.25), vec3(0.12, 0.22, 0.1), land);
		float clouds = smoothstep(0.5, 0.8, fbm(q * 2.6 + 11.0));
		surface = mix(surface, vec3(0.85, 0.88, 0.92), clouds * 0.75);
		float lit = clamp(0.35 + 0.65 * dot(normalize(vec3(L.x, 0.4, L.z)), vec3(0.0, 1.0, 0.0)), 0.15, 1.0);
		// haze near the limb, the atmosphere seen edge on
		float haze = exp(-below * 9.0);
		surface = mix(surface * lit, vec3(0.35, 0.6, 1.0) * lit, haze * 0.75);
		col = surface;
	}
	// thin glowing limb just above the surface
	float limb = exp(-abs(d.y - limb_y) * 70.0);
	col += vec3(0.25, 0.55, 1.0) * limb * 0.9;

	COLOR = col;
}

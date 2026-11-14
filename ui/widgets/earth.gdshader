shader_type canvas_item;
// Procedural Earth on a square rect: fbm continents, ice caps, drifting clouds,
// a soft day/night terminator and a blue rim. Sun comes from the left.

uniform float spin = 0.0;
// tilts the globe toward or away from the viewer, radians
uniform float pitch = 0.0;
uniform vec3 sun_dir = vec3(-0.85, -0.25, 0.45);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	if (r2 > 1.0) {
		COLOR = vec4(0.0);
	} else {
		vec3 n = vec3(p.x, p.y, sqrt(1.0 - r2));
		// surface lookup uses the tilted normal, lighting keeps the view normal
		float cp = cos(pitch);
		float sp = sin(pitch);
		vec3 g = vec3(n.x, n.y * cp - n.z * sp, n.y * sp + n.z * cp);
		float lon = atan(g.x, g.z) + spin;
		float lat = asin(clamp(g.y, -1.0, 1.0));
		vec2 q = vec2(lon * 1.6, lat * 2.2);
		float h = fbm(q * 1.7 + vec2(3.1, 1.7));
		vec3 ocean = mix(vec3(0.04, 0.18, 0.45), vec3(0.09, 0.36, 0.68), n.z);
		vec3 land = mix(vec3(0.15, 0.42, 0.22), vec3(0.58, 0.5, 0.3), smoothstep(0.62, 0.78, h));
		vec3 col = mix(ocean, land, smoothstep(0.54, 0.56, h));
		col = mix(col, vec3(0.92, 0.95, 1.0), smoothstep(0.84, 0.9, abs(g.y)));
		float clouds = smoothstep(0.55, 0.78, fbm(q * 3.0 + vec2(spin * 0.6 + 7.0, 3.0)));
		col = mix(col, vec3(1.0), clouds * 0.55);

		float d = dot(n, normalize(sun_dir));
		float day = smoothstep(-0.12, 0.22, d);
		vec3 night = col * 0.05 + vec3(0.015, 0.02, 0.05);
		col = mix(night, col * (0.4 + 0.7 * max(d, 0.0)), day);
		float rim = pow(1.0 - n.z, 2.5);
		col += vec3(0.3, 0.6, 1.0) * rim * (0.15 + 0.6 * day);
		COLOR = vec4(col, smoothstep(1.0, 0.985, r2));
	}
}

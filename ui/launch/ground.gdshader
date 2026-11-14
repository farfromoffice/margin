shader_type spatial;
// Coastal scrubland around the pad: scrub and dry grass, a sand beach, the sea
// with moving waves, and a concrete apron under the pad. All from world space
// noise, so one big plane is enough and nothing tiles visibly.

uniform float pad_radius = 180.0;
uniform float coast_x = 900.0;

varying vec3 wpos;

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
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float n = fbm(p * 0.004);
	float n2 = fbm(p * 0.03 + 17.0);
	float n3 = fbm(p * 0.25);

	vec3 scrub = mix(vec3(0.13, 0.19, 0.08), vec3(0.27, 0.30, 0.15), n);
	scrub = mix(scrub, vec3(0.45, 0.40, 0.26), smoothstep(0.55, 0.78, n2));
	scrub *= 0.82 + 0.36 * n3;

	float coast = coast_x + (fbm(vec2(3.0, p.y * 0.0015)) - 0.5) * 600.0;
	float beach = smoothstep(coast - 70.0, coast - 15.0, p.x);
	vec3 sand = vec3(0.78, 0.72, 0.57) * (0.92 + 0.16 * n3);
	vec3 land = mix(scrub, sand, beach);

	float apron = 1.0 - smoothstep(pad_radius * 0.85, pad_radius, length(p));
	vec3 concrete = vec3(0.4, 0.39, 0.37) * (0.9 + 0.15 * n3);
	land = mix(land, concrete, apron);

	float water = smoothstep(coast - 4.0, coast + 4.0, p.x);
	vec2 flow = vec2(TIME * 0.6, TIME * 0.25);
	float w1 = fbm(p * 0.045 + flow);
	float w2 = fbm(p * 0.11 - flow * 1.7);
	vec3 deep = mix(vec3(0.02, 0.10, 0.16), vec3(0.05, 0.20, 0.27), w1);
	float shallow = 1.0 - smoothstep(0.0, 120.0, p.x - coast);
	vec3 sea = mix(deep, vec3(0.16, 0.40, 0.42), shallow * 0.6);
	// surf line where the waves break on the sand
	float surf = smoothstep(0.55, 0.8, w2) * (1.0 - smoothstep(0.0, 35.0, p.x - coast));
	sea = mix(sea, vec3(0.85, 0.88, 0.86), surf);

	ALBEDO = mix(land, sea, water);
	ROUGHNESS = mix(mix(0.95, 0.85, apron), 0.06 + 0.1 * w2, water);
	SPECULAR = mix(0.25, 0.7, water);

	// hmm, cheap wave normals: tilt by the noise gradient, only on water
	float e = 1.5;
	float hx = fbm((p + vec2(e, 0.0)) * 0.11 - flow * 1.7) - w2;
	float hz = fbm((p + vec2(0.0, e)) * 0.11 - flow * 1.7) - w2;
	vec3 n_world = normalize(vec3(-hx * 2.5, 1.0, -hz * 2.5));
	vec3 n_view = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, n_view, water));
}

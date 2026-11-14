shader_type canvas_item;
// Earth on a square rect from NASA imagery: Blue Marble for the day side, Black
// Marble city lights for the night side, procedural clouds drifting on top, a
// soft day/night terminator and a blue rim. Sun comes from the left.

uniform float spin = 0.0;
// tilts the globe toward or away from the viewer, radians
uniform float pitch = 0.0;
uniform vec3 sun_dir = vec3(-0.85, -0.25, 0.45);
uniform sampler2D day_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D night_map : source_color, filter_linear_mipmap, repeat_enable;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), u.x);
	float b = mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), u.x);
	float c = mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), u.x);
	float d = mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), u.x);
	return mix(mix(a, b, u.y), mix(c, d, u.y), u.z);
}

// fbm3 samples noise on the sphere itself. Lat/lon noise pinches into streaks
// at the poles.
float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise3(p);
		p *= 2.07;
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
		// canvas y points down, north is negative y
		float lat = asin(clamp(-g.y, -1.0, 1.0));

		// equirectangular maps: u runs from 180 w to 180 e, v from the north pole
		// down. u jumps from 1 to 0 at the date line and the mip level picked from
		// that jump would draw a seam.
		// the gradient comes from a copy of u shifted half a turn, which is continuous there.
		vec2 uv = vec2(fract(lon / TAU + 0.5), 0.5 - lat / PI);
		vec2 uv_shifted = vec2(fract(lon / TAU), uv.y);
		vec2 dx = dFdx(uv);
		vec2 dy = dFdy(uv);
		vec2 dx_s = dFdx(uv_shifted);
		vec2 dy_s = dFdy(uv_shifted);
		if (dot(dx_s, dx_s) + dot(dy_s, dy_s) < dot(dx, dx) + dot(dy, dy)) {
			dx = dx_s;
			dy = dy_s;
		}
		dx.x *= cos(lat);
		dy.x *= cos(lat);
		vec3 col = textureGrad(day_map, uv, dx, dy).rgb;
		vec3 lights = textureGrad(night_map, uv, dx, dy).rgb;

		float cloud_lon = lon + spin * 0.6;
		vec3 sc = vec3(sin(cloud_lon) * cos(lat), g.y, cos(cloud_lon) * cos(lat));
		float clouds = smoothstep(0.5, 0.72, fbm3(sc * 6.5 + vec3(7.0, 3.0, 1.0)));
		col = mix(col, vec3(1.0), clouds * 0.5);

		float d = dot(n, normalize(sun_dir));
		float day = smoothstep(-0.12, 0.22, d);
		// Black Marble also has a moonlit layer where ice and deserts read about
		// 0.17 and lean blue while city light is warm. Taking half the blue off
		// red and green drops the moonlit layer to zero and keeps dim suburbs.
		// The faint day map stands in for the moonlight.
		float city = smoothstep(0.03, 0.3, min(lights.r, lights.g) - 0.5 * lights.b);
		vec3 night = vec3(1.0, 0.78, 0.48) * city * 1.3 * (1.0 - clouds * 0.6) + col * 0.04 + vec3(0.008, 0.012, 0.025);
		col = mix(night, col * (0.45 + 0.75 * max(d, 0.0)), day);
		float rim = pow(1.0 - n.z, 2.5);
		col += vec3(0.3, 0.6, 1.0) * rim * (0.15 + 0.6 * day);
		COLOR = vec4(col, smoothstep(1.0, 0.985, r2));
	}
}

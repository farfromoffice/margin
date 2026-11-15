// The main menu globe from the game, in WebGL2. The fragment shader is a port of
// ui/widgets/earth.gdshader and the ring and craft follow ui/widgets/orbit_view.gd,
// so keep the two in step when the game's globe changes.
(() => {
	"use strict";

	const root = document.querySelector("[data-globe]");
	if (!root) return;

	const back = root.querySelector(".globe__back");
	const planet = root.querySelector(".globe__planet");
	const front = root.querySelector(".globe__front");
	const gl = planet.getContext("webgl2", { premultipliedAlpha: false, antialias: true });
	if (!gl) return; // the CSS keeps the screenshot fallback visible

	const VERT = `#version 300 es
in vec2 a_pos;
out vec2 v_uv;
void main() {
	// canvas y points down in the Godot shader, so flip it here and keep the math the same
	v_uv = vec2(a_pos.x * 0.5 + 0.5, 0.5 - a_pos.y * 0.5);
	gl_Position = vec4(a_pos, 0.0, 1.0);
}`;

	const FRAG = `#version 300 es
precision highp float;
in vec2 v_uv;
out vec4 o;
uniform float spin;
uniform float pitch;
uniform vec3 sun_dir;
uniform sampler2D day_map;
uniform sampler2D night_map;
const float PI = 3.14159265;
const float TAU = 6.28318531;

float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

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

float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise3(p); p *= 2.07; a *= 0.5; }
	return v;
}

void main() {
	vec2 p = v_uv * 2.0 - 1.0;
	float r2 = dot(p, p);
	if (r2 > 1.0) { o = vec4(0.0); return; }
	vec3 n = vec3(p.x, p.y, sqrt(1.0 - r2));
	float cp = cos(pitch);
	float sp = sin(pitch);
	vec3 g = vec3(n.x, n.y * cp - n.z * sp, n.y * sp + n.z * cp);
	float lon = atan(g.x, g.z) + spin;
	float lat = asin(clamp(-g.y, -1.0, 1.0));

	// same date line trick as the game: take the gradient from whichever copy of u is continuous
	vec2 uv = vec2(fract(lon / TAU + 0.5), 0.5 - lat / PI);
	vec2 uv_s = vec2(fract(lon / TAU), uv.y);
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	vec2 dx_s = dFdx(uv_s);
	vec2 dy_s = dFdy(uv_s);
	if (dot(dx_s, dx_s) + dot(dy_s, dy_s) < dot(dx, dx) + dot(dy, dy)) { dx = dx_s; dy = dy_s; }
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
	float city = smoothstep(0.03, 0.3, min(lights.r, lights.g) - 0.5 * lights.b);
	vec3 night = vec3(1.0, 0.78, 0.48) * city * 1.3 * (1.0 - clouds * 0.6) + col * 0.04 + vec3(0.008, 0.012, 0.025);
	col = mix(night, col * (0.45 + 0.75 * max(d, 0.0)), day);
	float rim = pow(1.0 - n.z, 2.5);
	col += vec3(0.3, 0.6, 1.0) * rim * (0.15 + 0.6 * day);
	// Godot's 2D canvas blends in sRGB too, so the values go out as they are
	o = vec4(col, smoothstep(1.0, 0.985, r2));
}`;

	function compile(type, src) {
		const s = gl.createShader(type);
		gl.shaderSource(s, src);
		gl.compileShader(s);
		if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
		return s;
	}

	let prog;
	try {
		prog = gl.createProgram();
		gl.attachShader(prog, compile(gl.VERTEX_SHADER, VERT));
		gl.attachShader(prog, compile(gl.FRAGMENT_SHADER, FRAG));
		gl.linkProgram(prog);
		if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(prog));
	} catch (e) {
		console.warn("globe: shader failed, keeping the screenshot", e);
		return;
	}
	gl.useProgram(prog);

	const buf = gl.createBuffer();
	gl.bindBuffer(gl.ARRAY_BUFFER, buf);
	gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
	const loc = gl.getAttribLocation(prog, "a_pos");
	gl.enableVertexAttribArray(loc);
	gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);

	const u = (name) => gl.getUniformLocation(prog, name);
	const uSpin = u("spin");
	const uPitch = u("pitch");
	gl.uniform3f(u("sun_dir"), -0.85, -0.25, 0.45);
	gl.uniform1i(u("day_map"), 0);
	gl.uniform1i(u("night_map"), 1);
	gl.enable(gl.BLEND);
	gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

	function texture(unit, src) {
		return new Promise((resolve, reject) => {
			const img = new Image();
			img.onload = () => {
				const t = gl.createTexture();
				gl.activeTexture(gl.TEXTURE0 + unit);
				gl.bindTexture(gl.TEXTURE_2D, t);
				gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, gl.RGB, gl.UNSIGNED_BYTE, img);
				gl.generateMipmap(gl.TEXTURE_2D);
				gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
				gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
				gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
				gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
				resolve();
			};
			img.onerror = reject;
			img.src = src;
		});
	}

	const sat = new Image();
	sat.src = "img/satellite.svg";

	const CYAN = "99, 210, 255"; // UiStyle.CYAN
	const ACCENT = "242, 169, 59"; // UiStyle.ACCENT

	// numbers straight from orbit_view.gd
	const SPIN_SPEED = 0.35;
	const ECLIPSE = 0.36;
	const TILT = -0.32;
	const IDLE_SPIN = -0.05;
	const DRAG_RAD_PER_PX = 0.008;
	const MAX_PITCH = 0.9;

	const reduce = window.matchMedia("(prefers-reduced-motion: reduce)");
	let angle = 0.6;
	let earthSpin = 0;
	let pitch = 0;
	let fling = 0;
	let dragging = false;
	let last = 0;
	let visible = true;
	let w = 0, h = 0, dpr = 1;

	function resize() {
		dpr = Math.min(window.devicePixelRatio || 1, 2);
		const rect = root.getBoundingClientRect();
		w = rect.width;
		h = rect.height;
		for (const c of [back, planet, front]) {
			c.width = Math.round(w * dpr);
			c.height = Math.round(h * dpr);
		}
	}

	// the ring reaches about 2 radii sideways once tilted, so the width decides; the game
	// does the same with min(width / 2.2, height) * 0.32 on its wider control
	const radius = () => Math.min(w / 4.2, h * 0.4);
	const ring = () => { const r = radius(); return [r * 1.9, r * 0.62]; };

	function onRing(cx, cy, a) {
		const [rx, ry] = ring();
		const x = Math.cos(a) * rx;
		const y = Math.sin(a) * ry;
		const c = Math.cos(TILT), s = Math.sin(TILT);
		return [cx + x * c - y * s, cy + x * s + y * c];
	}

	function drawRing(ctx, from, to, alpha) {
		const cx = w / 2, cy = h / 2;
		ctx.beginPath();
		for (let i = 0; i <= 64; i++) {
			const [x, y] = onRing(cx, cy, from + (to - from) * i / 64);
			i ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
		}
		ctx.strokeStyle = `rgba(${CYAN}, ${alpha})`;
		ctx.lineWidth = 1.5;
		ctx.stroke();
	}

	function drawSat(ctx, inShadow) {
		const [x, y] = onRing(w / 2, h / 2, angle);
		const s = Math.max(22, Math.min(44, radius() * 0.32));
		if (!inShadow) {
			ctx.beginPath();
			ctx.arc(x, y, s * 0.55, 0, Math.PI * 2);
			ctx.fillStyle = `rgba(${ACCENT}, 0.16)`;
			ctx.fill();
		}
		if (sat.complete && sat.naturalWidth) {
			// in the shadow the game modulates the icon to a dim blue grey
			ctx.globalAlpha = inShadow ? 0.5 : 1;
			ctx.drawImage(sat, x - s / 2, y - s / 2, s, s);
			ctx.globalAlpha = 1;
		}
	}

	function frame(t) {
		const delta = last ? Math.min((t - last) / 1000, 0.1) : 0;
		last = t;
		const still = reduce.matches;

		if (!still) angle = (angle + delta * SPIN_SPEED) % (Math.PI * 2);
		const wrapped = Math.atan2(Math.sin(angle), Math.cos(angle));
		const inShadow = Math.abs(wrapped) < ECLIPSE * Math.PI;
		if (!dragging) {
			earthSpin += (still ? 0 : IDLE_SPIN + fling) * delta;
			fling *= Math.exp(-1.8 * delta);
		}

		const r = radius();
		gl.viewport(
			Math.round((w / 2 - r) * dpr), Math.round((h / 2 - r) * dpr),
			Math.round(r * 2 * dpr), Math.round(r * 2 * dpr)
		);
		gl.clearColor(0, 0, 0, 0);
		const full = [0, 0, planet.width, planet.height];
		gl.enable(gl.SCISSOR_TEST);
		gl.scissor(...full);
		gl.clear(gl.COLOR_BUFFER_BIT);
		gl.disable(gl.SCISSOR_TEST);
		gl.uniform1f(uSpin, earthSpin);
		gl.uniform1f(uPitch, pitch);
		gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);

		const behind = Math.sin(angle) < 0;
		for (const [c, isBack] of [[back, true], [front, false]]) {
			const ctx = c.getContext("2d");
			ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
			ctx.clearRect(0, 0, w, h);
			if (isBack) {
				// soft blue halo, ten faint discs like the game draws
				for (let i = 0; i < 10; i++) {
					ctx.beginPath();
					ctx.arc(w / 2, h / 2, r * (1.16 - i * 0.015), 0, Math.PI * 2);
					ctx.fillStyle = "rgba(89, 166, 255, 0.03)";
					ctx.fill();
				}
				drawRing(ctx, Math.PI, Math.PI * 2, 0.22);
				if (behind) drawSat(ctx, inShadow);
			} else {
				drawRing(ctx, 0, Math.PI, 0.55);
				if (!behind) drawSat(ctx, inShadow);
			}
		}

		if (visible) requestAnimationFrame(frame);
	}

	function overPlanet(e) {
		const rect = root.getBoundingClientRect();
		const dx = e.clientX - rect.left - w / 2;
		const dy = e.clientY - rect.top - h / 2;
		return Math.hypot(dx, dy) <= radius();
	}

	front.addEventListener("pointerdown", (e) => {
		if (!overPlanet(e)) return;
		dragging = true;
		fling = 0;
		front.setPointerCapture(e.pointerId);
	});
	front.addEventListener("pointermove", (e) => {
		front.style.cursor = dragging ? "grabbing" : overPlanet(e) ? "grab" : "";
		if (!dragging) return;
		const step = -e.movementX * DRAG_RAD_PER_PX;
		earthSpin += step;
		pitch = Math.max(-MAX_PITCH, Math.min(MAX_PITCH, pitch + e.movementY * DRAG_RAD_PER_PX * 0.7));
		// same rough fling as the game: one event is about one frame
		fling = Math.max(-6, Math.min(6, step * 60));
	});
	const release = () => { dragging = false; };
	front.addEventListener("pointerup", release);
	front.addEventListener("pointercancel", release);

	// don't burn a GPU on a globe nobody is looking at
	new IntersectionObserver(([entry]) => {
		const was = visible;
		visible = entry.isIntersecting;
		if (visible && !was) { last = 0; requestAnimationFrame(frame); }
	}).observe(root);

	new ResizeObserver(resize).observe(root);
	resize();

	Promise.all([texture(0, "img/blue_marble.jpg"), texture(1, "img/black_marble.jpg")])
		.then(() => {
			root.classList.add("is-live");
			requestAnimationFrame(frame);
		})
		.catch((e) => console.warn("globe: textures failed, keeping the screenshot", e));
})();

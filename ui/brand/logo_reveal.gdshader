shader_type canvas_item;

// 0 hides everything, 1 shows the whole logo. The edge between them is soft
// so the line looks like it's being drawn in, not wiped.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.001, 0.5) = 0.12;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	// hmm, stretch the range by softness so 0 and 1 really are fully hidden and fully shown
	float edge = progress * (1.0 + softness) - softness;
	c.a *= 1.0 - smoothstep(edge, edge + softness, UV.x);
	COLOR = c;
}

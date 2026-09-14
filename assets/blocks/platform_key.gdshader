shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// The supplied sheets use magenta outside the painted platforms.
	float spill = max(0.0, min(source.r, source.b) - source.g);
	float opacity = 1.0 - smoothstep(0.06, 0.32, spill);
	vec3 clean = source.rgb - vec3(spill, 0.0, spill);
	COLOR = vec4(max(clean, vec3(0.0)), source.a * opacity);
}

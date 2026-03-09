shader_type canvas_item;

// --- Uniforms --- //
uniform vec4 top_color: source_color = vec4(1.0);
uniform vec4 bottom_color: source_color = vec4(1.0);

// --- Functions --- //
void fragment() {
	COLOR = mix(top_color, bottom_color, UV.y);
}
shader_type canvas_item;

// --- Uniforms --- //
uniform vec4 flash_color: source_color = vec4(1.0);
uniform float intensity: hint_range(0.0, 1.0, 0.01) = 0.0;

// --- Functions --- //

void fragment() {
	COLOR.rgb = mix(COLOR, flash_color, intensity).rgb;
}

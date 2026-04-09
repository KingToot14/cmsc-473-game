shader_type canvas_item;

// --- Uniforms --- //
global uniform float current_time;

uniform sampler2D top_gradient;
uniform sampler2D bottom_gradient;

// --- Functions --- //
void fragment() {
	vec4 top_color = texture(top_gradient, vec2(current_time, 0.0));
	vec4 bottom_color = texture(bottom_gradient, vec2(current_time, 0.0));
	
	COLOR = mix(top_color, bottom_color, UV.y);
}
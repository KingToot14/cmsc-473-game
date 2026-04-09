shader_type canvas_item;
#include "res://scripts/shaders/generic.gdshaderinc"

// --- Uniforms --- //
uniform vec2 texture_size = vec2(48.0);

uniform float solid_size: hint_range(0.0, 64.0, 1.0) = 32.0;
uniform float decay_size: hint_range(0.0, 64.0, 1.0) = 16.0;

// --- Functions --- //
void fragment() {
	vec2 uv = pixelize(UV, texture_size);
	float dist = distance(uv, vec2(0.5)) * texture_size.x;
	
	COLOR.a *= 1.0 - smoothstep(solid_size, solid_size + decay_size, dist);
}
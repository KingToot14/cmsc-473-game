shader_type canvas_item;

// --- Variables --- //
global uniform vec2 mouse_position;

uniform float mouse_range: hint_range(0.0, 64.0, 2.0) = 16.0;
uniform float mouse_falloff: hint_range(0.0, 64.0, 2.0) = 16.0;

uniform float grid_size: hint_range(0.0, 16.0, 1.0) = 8.0;
uniform float line_size: hint_range(0.0, 4.0, 1.0) = 1.0;

varying vec2 world_position;

// --- Functions --- //
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// Reset COLOR
	vec4 color = COLOR;
	COLOR.a = 0.0;
	
	// Draw grid lines
	COLOR.a += step(mod(world_position.x, grid_size), line_size);
	COLOR.a += step(mod(world_position.y, grid_size), line_size);
	COLOR.a = min(COLOR.a, 1.0);
	
	// Fade out based on mouse
	float fadeout = 1.0 - smoothstep(
		mouse_range, mouse_range + mouse_falloff,
		distance(mouse_position, world_position)
	);
	COLOR.a *= fadeout;
	
	// Respect original alpha
	COLOR.a *= color.a; 
}
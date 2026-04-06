shader_type canvas_item;

// --- Uniforms --- //
global uniform sampler2D lava_texture: filter_nearest;
global uniform vec2 water_offset;
uniform vec4 water_color: source_color = vec4(0.0, 0.0, 1.0, 0.6);
uniform vec4 foam_color: source_color = vec4(0.0, 0.0, 1.0, 0.6);

varying vec2 world_position;

// --- Functions --- //
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 tile_position = world_position / 8.0 - water_offset;
	vec2 local_position = vec2(mod(world_position.x, 8.0), mod(world_position.y, 8.0));
	
	vec2 tex_size = vec2(textureSize(lava_texture, 0));
	
	// Get water level from red channel
	float water_level = texture(lava_texture, tile_position / tex_size).r;
	float local_level = (8.0 - local_position.y) / 8.0;
	
	// Make sure at least 1 pixel of water is rendered (if water exists)
	water_level = step(0.001, water_level) * max(water_level, 0.125);
	
	// Neighbors levels 
	float top_level = texture(lava_texture, (tile_position - vec2(0.0, 1.0)) / tex_size).r;
	float bottom_level = texture(lava_texture, (tile_position + vec2(0.0, 1.0)) / tex_size).r;
	float left_level = texture(lava_texture, (tile_position - vec2(1.0, 0.0)) / tex_size).r;
	float right_level = texture(lava_texture, (tile_position + vec2(1.0, 0.0)) / tex_size).r;
	
	// Combine water columns
	water_level = step(0.001, water_level) * mix(water_level, 1.0, step(0.001, top_level));
	
	// Set base color
	COLOR = water_color;
	
	// Color edges
	float foam_top = step(water_level - 0.125, local_level);
	foam_top = foam_top * step(top_level, 0.0);
	COLOR = mix(COLOR, foam_color, foam_top);
	
	float foam_bottom = step(local_level, 0.125);
	foam_bottom = foam_bottom * step(bottom_level, 0.0);
	COLOR = mix(COLOR, foam_color, foam_bottom);
	
	float foam_left = step(local_position.x, 1.0);
	foam_left = foam_left * step(left_level, local_level);
	COLOR = mix(COLOR, foam_color, foam_left);
	
	float foam_right = step(7.0, local_position.x);
	foam_right = foam_right * step(right_level, local_level);
	COLOR = mix(COLOR, foam_color, foam_right);
	
	// remove corners
	COLOR.a *= step(foam_top + foam_left + foam_right, 1.0);
	COLOR.a *= step(foam_bottom + foam_left + foam_right, 1.0);
	COLOR.a = mix(COLOR.a, foam_color.a, step(1.5, foam_top + foam_bottom));
	
	// Only color up to water level
	COLOR.a *= step(local_level, water_level);
}
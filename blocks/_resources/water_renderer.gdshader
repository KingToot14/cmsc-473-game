shader_type canvas_item;

// --- Uniforms --- //
global uniform sampler2D water_texture: filter_nearest;
global uniform vec2 water_offset;
uniform vec4 water_color: source_color = vec4(0.0, 0.0, 1.0, 0.6);

varying vec2 world_position;

// --- Functions --- //
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 tile_position = world_position / 8.0 - water_offset;
	vec2 local_position = vec2(mod(world_position.x, 8.0), mod(world_position.y, 8.0));
	
	vec2 tex_size = vec2(textureSize(water_texture, 0));
	
	float water_level = 1.0 - texture(water_texture, tile_position / tex_size).r;
	
	COLOR = water_color;
	COLOR.a *= step(water_level, local_position.y / 8.0);
}
shader_type canvas_item;
render_mode blend_mul;

// --- Uniforms --- //
global uniform sampler2D light_texture: filter_linear;
global uniform sampler2D sky_texture: filter_linear;
global uniform vec2 light_offset;
global uniform float current_time;

uniform sampler2D sky_gradient;
//uniform vec4 sky_color: source_color = vec4(1.0);

varying vec2 world_position;

// --- Functions --- //
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 tile_position = world_position / 8.0 - light_offset;
	vec2 local_position = vec2(mod(world_position.x, 8.0), mod(world_position.y, 8.0));
	
	vec2 tex_size = vec2(textureSize(light_texture, 0));
	vec4 sky_color = texture(sky_gradient, vec2(current_time, 0.0));
	
	vec4 color = texture(light_texture, tile_position / tex_size) + 
		sky_color * texture(sky_texture, tile_position / tex_size).r;
	
	COLOR *= color;
}
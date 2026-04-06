shader_type canvas_item;

// --- Uniforms --- //
global uniform sampler2D lava_texture: filter_linear;
global uniform vec2 water_offset;

uniform vec4 glow_color: source_color = vec4(1.0, 0.4, 0.0, 0.6);

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
	float lava_level = texture(lava_texture, tile_position / tex_size).r;
	float local_level = (8.0 - local_position.y) / 8.0;
	
	// Calculate brightness
	float brightness = step(0.01, lava_level) * mix(0.6, 1.0, smoothstep(0.0, 0.3, lava_level));;
	
	// Neighbors levels 
	float tl = texture(lava_texture, (tile_position + vec2(-1.0, -1.0)) / tex_size).r;
	float tm = texture(lava_texture, (tile_position + vec2( 0.0, -1.0)) / tex_size).r;
	float tr = texture(lava_texture, (tile_position + vec2( 1.0, -1.0)) / tex_size).r;
	float ml = texture(lava_texture, (tile_position + vec2(-1.0,  0.0)) / tex_size).r;
	float mr = texture(lava_texture, (tile_position + vec2( 1.0,  0.0)) / tex_size).r;
	float bl = texture(lava_texture, (tile_position + vec2(-1.0,  1.0)) / tex_size).r;
	float bm = texture(lava_texture, (tile_position + vec2( 0.0,  1.0)) / tex_size).r;
	float br = texture(lava_texture, (tile_position + vec2( 1.0,  1.0)) / tex_size).r;
	
	float neighbor_avg = (tl + tm + tr + ml + mr + bl + bm + br) * 0.125;
	
	COLOR = glow_color * max(neighbor_avg, brightness);
}
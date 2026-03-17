shader_type canvas_item;

// --- Uniforms --- //
uniform vec4 primary_color: source_color = vec4(1.0);
uniform vec4 secondary_color: source_color = vec4(1.0);

// --- Functions --- //
void fragment() {
	vec4 color = COLOR;
	
	// Reset color
	COLOR.rgb = vec3(0.0);
	
	// Add secondary colors 
	COLOR.rgb += primary_color.rgb * color.r;
	COLOR.rgb += secondary_color.rgb * color.g; 
}

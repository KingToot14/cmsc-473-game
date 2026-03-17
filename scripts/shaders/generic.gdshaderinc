// --- Functions --- //
vec2 pixelize(vec2 _uv, vec2 _texture_size) {
	return round(_uv * (_texture_size + 1.0) - (_uv - 0.5)) / (_texture_size + 1.0);
}

vec2 rotate_to(vec2 _pos, float _rotation) {
	return vec2(_pos.x * cos(_rotation) + _pos.y * -sin(_rotation), _pos.x * sin(_rotation) + _pos.y * cos(_rotation));
}
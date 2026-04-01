class_name LightManager
extends ColorRect

# --- Variables --- #
@export var light_shader: ShaderMaterial
@export var light_gradient: GradientTexture1D

var curr_minute := -1

# --- Functions --- #
func _ready() -> void:
	if OS.has_feature('dedicated_server'):
		set_process(false)

func _process(_delta: float) -> void:
	# update sky
	light_shader.set_shader_parameter(
		&'sky_color',
		light_gradient.get_image().get_pixel(
			floori(DaytimeManager.curr_time_percent * 960), 0
		)
	)

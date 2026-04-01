class_name Background
extends Node2D

# --- Variables --- #
const TRANSITION_TIME := 0.50

var tween: Tween

@export_flags(
	'space', 'surface', 'underground', 'cavern', 'underworld'
) var allowed_layers := 0

@export_flags(
	'forest', 'desert', 'snow', 'ocean'
) var allowed_biomes := 0

@export var sky_shader: ShaderMaterial
@export var sky_gradient_top: GradientTexture1D
@export var sky_gradient_bottom: GradientTexture1D

# --- Functions --- #
func _ready() -> void:
	if OS.has_feature('dedicated_server') or sky_shader == null:
		set_process(false)

func _process(_delta: float) -> void:
	if not visible:
		return
	
	# update sky
	var gradient_pos := DaytimeManager.curr_time_percent * 960
	
	sky_shader.set_shader_parameter(
		&'top_color',
		sky_gradient_top.get_image().get_pixel(floori(gradient_pos), 0)
	)
	sky_shader.set_shader_parameter(
		&'bottom_color',
		sky_gradient_bottom.get_image().get_pixel(floori(gradient_pos), 0)
	)

func update_background(biome: BiomeManager.Biome, layer: BiomeManager.Layer) -> void:
	if (biome & allowed_biomes) and (layer & allowed_layers):
		if tween:
			tween.kill()
		tween = create_tween()
		
		tween.tween_property(self, ^'modulate:a', 1.0, TRANSITION_TIME)
	else:
		if tween:
			tween.kill()
		tween = create_tween()
		
		tween.tween_property(self, ^'modulate:a', 0.0, TRANSITION_TIME)

class_name SunManager
extends Node2D

# --- Variables --- #
@export var bodies: Array[Node2D] = []
@export var radius := 650

# --- Functions --- #
func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		set_process(false)

func _process(_delta: float) -> void:
	var base_angle := (2.0 * PI) / 3.0 * DaytimeManager.curr_time_percent + PI / 6.0 + PI / 3.0
	
	for i in range(len(bodies)):
		var angle := base_angle + (i * PI) / (len(bodies) / 2.0)
		
		bodies[i].position = radius * Vector2(cos(angle), sin(angle))

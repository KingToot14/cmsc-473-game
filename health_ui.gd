class_name HealthUI
extends CanvasLayer

@onready var progress_bar = $health_bar
var player_hp: PlayerHp

func setup_ui(hp_node: PlayerHp) -> void:
	player_hp = hp_node
	
	# Set initial bar values
	progress_bar.max_value = player_hp.max_hp
	progress_bar.value = player_hp.curr_hp
	
	# Connect to the hp_modified signal to automatically update
	player_hp.hp_modified.connect(_on_hp_modified)

func _on_hp_modified(_delta: int) -> void:
	# Update the bar whenever health changes
	progress_bar.value = player_hp.curr_hp

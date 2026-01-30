extends Node

# --- Variables --- #
var world_size := Vector2i(160, 160)
var world_spawn: Vector2i

# --- Functions --- #
func parse_arguments() -> Dictionary:
	var arguments: Dictionary = {}
	
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		arg = arg.replace('--', '')
		if arg.contains('='):
			var tokens := arg.split('=')
			arguments[tokens[0]] = tokens[1]
		else:
			arguments[arg] = true
	
	return arguments

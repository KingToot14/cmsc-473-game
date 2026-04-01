extends Node

## An Autoload that manages the day/night cycle in the loaded world. This provides
## getters for the current time, hour, minutes, and a few other functions.

# --- Variables --- #
## How much [member NetworkTIme.time] should be offset for this world. This
## should only be modified during world loading.
var daytime_offset := daytime_time / 2.0	# start at noon
## How many seconds are in each day
var daytime_time := (60.0 * 24.0) / 24.0	# 24 minutes for whole cycle
## How many hours are in each day (should divide [member daytime_time] nicely).
var daytime_hours := 24
## Determines how [member curr_minute] is snapped. For a value of [code]15[/code],
## this means that [member curr_minute] can only be one of [code]0, 15, 30, 45[/code]
var daytime_minute_intervals := 15

## The current time in seconds, wrapping back to 0 at the start of each day.
var curr_time: float:
	get():
		return fmod(NetworkTime.time + daytime_offset, daytime_time)

## The current time as a value from [code]0.0[/code] to [code]1.0[/code].
var curr_time_percent: float:
	get():
		return curr_time / daytime_time

## The current hour as an integer. Wraps around after [member daytime_hours].
var curr_hour: int:
	get():
		return floori(curr_time / (daytime_time / daytime_hours))

## The current minute as an integer from [code]0 - 60[/code]. Snapped to a multiple of 
## [member daytime_minute_invervals].
var curr_minute: int:
	get():
		var hour_secs := daytime_time / daytime_hours
		var minutes := floori(fmod(curr_time, hour_secs) / hour_secs * 60.0)
		
		# snap to intervals of 15 minutes
		return floori(float(minutes) / daytime_minute_intervals) * daytime_minute_intervals

var _internal_hour := -1

# --- Functions --- #
func _ready() -> void:
	# add node for synchronization
	var sync = MultiplayerSynchronizer.new()
	var config = SceneReplicationConfig.new()
	sync.set_multiplayer_authority(Globals.SERVER_ID)
	
	# set synced properties
	config.add_property(^':daytime_offset')
	config.property_set_replication_mode(
		^':daytime_offset',
		SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
	)
	
	config.add_property(^':daytime_time')
	config.property_set_replication_mode(
		^':daytime_time',
		SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
	)
	
	sync.replication_config = config
	add_child(sync)

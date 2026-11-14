class_name MissionClock
extends RefCounted
## MissionClock turns real seconds into whole simulation steps. The number of steps
## depends only on the real time at each speed, not on the frame rate.


## Mission seconds per real second at 1x. One mission day takes 6 real seconds.
const SIM_S_PER_REAL_S := 14400.0
const SPEEDS: Array[int] = [1, 4, 16]
## Upper limit of steps per advance, one mission day. A long frame loses time
## instead of fast forwarding the mission.
const MAX_STEPS_PER_ADVANCE := 1440

var dt_s := 60.0
var speed := 1
var paused := false

## Mission seconds owed since the last rebase and the steps already returned for
## them. Counting from a running total keeps rounding errors from adding up.
var _owed_s := 0.0
var _steps_given := 0


func _init(p_dt_s := 60.0) -> void:
	dt_s = p_dt_s


## advance returns how many steps to run for real_delta_s seconds of real time at
## the current speed.
func advance(real_delta_s: float) -> int:
	if paused or real_delta_s <= 0.0:
		return 0
	_owed_s += real_delta_s * SIM_S_PER_REAL_S * speed
	# The epsilon absorbs float error in summed frame times, for example 360 frames
	# of 1/60 s.
	var due := int(floor(_owed_s / dt_s + 1e-6)) - _steps_given
	if due > MAX_STEPS_PER_ADVANCE:
		_owed_s = 0.0
		_steps_given = 0
		return MAX_STEPS_PER_ADVANCE
	_steps_given += due
	return due


func set_speed(p_speed: int) -> void:
	_rebase()
	speed = p_speed


## set_paused pauses or resumes the clock and drops any unfinished part of a step.
func set_paused(on: bool) -> void:
	paused = on
	_owed_s = 0.0
	_steps_given = 0


func _rebase() -> void:
	_owed_s -= _steps_given * dt_s
	_steps_given = 0

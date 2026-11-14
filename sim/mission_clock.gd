class_name MissionClock
extends RefCounted
## Turns real seconds into whole simulation steps. The step count depends only
## on the real time that passed at each speed.


## 1x: one mission day every 6 real seconds
const SIM_S_PER_REAL_S := 14400.0
const SPEEDS: Array[int] = [1, 4, 16]
## a frame never runs more than one mission day; a hitch drops time instead of
## fast forwarding the mission
const MAX_STEPS_PER_ADVANCE := 1440

var dt_s := 60.0
var speed := 1
var paused := false

## mission seconds owed since the last rebase and the steps already handed out
## for them. Counting from a running total keeps per frame rounding from piling up.
var _owed_s := 0.0
var _steps_given := 0


func _init(p_dt_s := 60.0) -> void:
	dt_s = p_dt_s


## Steps to run for real_delta_s seconds of wall time.
func advance(real_delta_s: float) -> int:
	if paused or real_delta_s <= 0.0:
		return 0
	_owed_s += real_delta_s * SIM_S_PER_REAL_S * speed
	# the epsilon absorbs float error in summed frame times, e.g. 360 x 1/60
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


## Pausing drops the unfinished part of a step, resuming starts clean.
func set_paused(on: bool) -> void:
	paused = on
	_owed_s = 0.0
	_steps_given = 0


func _rebase() -> void:
	_owed_s -= _steps_given * dt_s
	_steps_given = 0

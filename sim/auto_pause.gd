class_name AutoPause
extends RefCounted
## AutoPause checks the state after each simulation step and decides whether to
## stop the clock for the player. A trigger fires when a value crosses its level
## and stays quiet until it re-arms. DESIGN.md lists the levels and the reasons.

const LOW_BATTERY := &"low_battery"
const STORAGE_HIGH := &"storage_high"
const CONTACT_BEGIN := &"contact_begin"
const SAFE_ENTER := &"safe_enter"
const FAILURE := &"failure"
const TRIGGERS: Array[StringName] = [FAILURE, LOW_BATTERY, STORAGE_HIGH, CONTACT_BEGIN, SAFE_ENTER]

## The low battery pause fires this far above Safe mode entry, while the controls
## can still keep the spacecraft out of Safe mode.
const LOW_BATTERY_MARGIN := 0.10
## A weak power design enters Safe mode several times a day. Without this cooldown
## every recharge re-arms the pause. One test mission paused 226 times.
const LOW_BATTERY_COOLDOWN_S := 86400.0
const STORAGE_PAUSE_FRACTION := 0.8
const STORAGE_REARM_FRACTION := 0.6

var enabled := {FAILURE: true, LOW_BATTERY: true, STORAGE_HIGH: true, CONTACT_BEGIN: true, SAFE_ENTER: false}
## Arming is tracked for disabled triggers too. Turning a trigger on in flight does
## not fire it for a condition that has been true for days.
var _armed := {LOW_BATTERY: true, STORAGE_HIGH: true, CONTACT_BEGIN: true}
var _low_battery_fired_t := -INF


static func low_battery_fraction(input: SimInput) -> float:
	return minf(input.safe_enter_fraction + LOW_BATTERY_MARGIN, input.safe_exit_fraction)


## check compares the state after a step with each trigger level and returns the
## enabled triggers that fired. mode_before is the mode the step ran in. The
## result is empty when nothing fired.
func check(s: SimState, input: SimInput, controls: Controls, mode_before: int) -> Array[StringName]:
	var fired: Array[StringName] = []
	# every failure is news, no arming needed: each kind strikes once per run
	if not s.failures_started.is_empty():
		fired.append(FAILURE)
	var capacity := s.capacity_j(input)

	if s.energy_j >= input.safe_exit_fraction * capacity:
		if s.t_s - _low_battery_fired_t >= LOW_BATTERY_COOLDOWN_S:
			_armed[LOW_BATTERY] = true
	elif _armed[LOW_BATTERY] and mode_before == RunResult.Mode.NORMAL \
			and s.energy_j <= low_battery_fraction(input) * capacity:
		_armed[LOW_BATTERY] = false
		_low_battery_fired_t = s.t_s
		fired.append(LOW_BATTERY)

	var storage := input.storage_capacity_bits
	if s.stored_bits < STORAGE_REARM_FRACTION * storage:
		_armed[STORAGE_HIGH] = true
	elif _armed[STORAGE_HIGH] and storage > 0.0 and s.stored_bits >= STORAGE_PAUSE_FRACTION * storage:
		_armed[STORAGE_HIGH] = false
		fired.append(STORAGE_HIGH)

	if mode_before == RunResult.Mode.NORMAL and s.mode == RunResult.Mode.SAFE:
		fired.append(SAFE_ENTER)

	# With the radio on the spacecraft transmits anyway. Only a pass the radio would
	# miss needs a decision.
	if _armed[CONTACT_BEGIN] and s.contact_starts > 0 and mode_before == RunResult.Mode.NORMAL \
			and not controls.radio_enabled:
		_armed[CONTACT_BEGIN] = false
		fired.append(CONTACT_BEGIN)

	return fired.filter(func(t): return enabled[t])


## rearm_contact lets the next pass with the radio off pause again. Mission calls it
## when the radio control changes.
func rearm_contact() -> void:
	_armed[CONTACT_BEGIN] = true

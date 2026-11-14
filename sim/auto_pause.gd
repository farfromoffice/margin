class_name AutoPause
extends RefCounted
## Decides after each simulation step whether to stop the clock so the player
## can act. Triggers fire on a crossing and stay quiet until they re-arm.
## A condition that stays true doesn't pause again.
## Levels and reasons in DESIGN.md ("Auto-pause").

const LOW_BATTERY := &"low_battery"
const STORAGE_HIGH := &"storage_high"
const CONTACT_BEGIN := &"contact_begin"
const SAFE_ENTER := &"safe_enter"
const TRIGGERS: Array[StringName] = [LOW_BATTERY, STORAGE_HIGH, CONTACT_BEGIN, SAFE_ENTER]

## the low battery pause sits this far above Safe mode entry while the
## controls can still keep the spacecraft out of it
const LOW_BATTERY_MARGIN := 0.10
## a weak power design cycles through Safe mode several times a day; without a
## cooldown every recharge would re-arm the pause (226 stops in one test mission)
const LOW_BATTERY_COOLDOWN_S := 86400.0
const STORAGE_PAUSE_FRACTION := 0.8
const STORAGE_REARM_FRACTION := 0.6

var enabled := {LOW_BATTERY: true, STORAGE_HIGH: true, CONTACT_BEGIN: true, SAFE_ENTER: false}
## arming is tracked even for disabled triggers, switching one on mid-flight
## doesn't fire on a condition that has been true for days
var _armed := {LOW_BATTERY: true, STORAGE_HIGH: true, CONTACT_BEGIN: true}
var _low_battery_fired_t := -INF


static func low_battery_fraction(input: SimInput) -> float:
	return minf(input.safe_enter_fraction + LOW_BATTERY_MARGIN, input.safe_exit_fraction)


## Call after every step with the mode the step ran in. Returns the enabled
## triggers that fired, empty if none.
func check(s: SimState, input: SimInput, controls: Controls, mode_before: int) -> Array[StringName]:
	var fired: Array[StringName] = []
	var capacity := input.battery_capacity_j

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

	# with the radio on, transmitting already is the decision; only a pass the
	# radio would let go by is worth a stop
	if _armed[CONTACT_BEGIN] and s.contact_starts > 0 and mode_before == RunResult.Mode.NORMAL \
			and not controls.radio_enabled:
		_armed[CONTACT_BEGIN] = false
		fired.append(CONTACT_BEGIN)

	return fired.filter(func(t): return enabled[t])


## The radio control changed; the next pass with the radio off may pause again.
func rearm_contact() -> void:
	_armed[CONTACT_BEGIN] = true

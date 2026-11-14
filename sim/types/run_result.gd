class_name RunResult
extends RefCounted
## What one simulated mission produced: per step series, totals, mode events and
## why it ended. The report and charts read this; daily() folds it into DayStates.

enum EndReason { COMPLETED, POWER_LOST }
enum Mode { NORMAL, SAFE }

var end_reason := EndReason.COMPLETED
var end_t_s := 0.0
var dt_s := 0.0

## one value per simulated step, recorded at the end of the step
var energy_j := PackedFloat64Array()
var stored_bits := PackedFloat64Array()
var delivered_bits := PackedFloat64Array()
var discarded_bits := PackedFloat64Array()
## Mode the step ran in
var mode := PackedByteArray()

var generated_bits_total := 0.0
var delivered_bits_total := 0.0
var discarded_bits_total := 0.0
var stored_bits_end := 0.0
## science the instrument would have taken while Safe. Not data, just blame.
var missed_bits_total := 0.0
var safe_time_s := 0.0
var safe_entries := 0

## [{t_s, kind (&"safe_enter" | &"safe_exit" | &"power_lost"), energy_j}]
var events: Array[Dictionary] = []


func step_count() -> int:
	return energy_j.size()


## One summary per simulated day, the last one may be partial.
func daily() -> Array[DayState]:
	var out: Array[DayState] = []
	if dt_s <= 0.0:
		return out
	var per_day := int(round(86400.0 / dt_s))
	var n := step_count()
	var prev_delivered := 0.0
	var prev_discarded := 0.0
	var ev := 0
	var first := 0
	while first < n:
		var last := mini(first + per_day, n) - 1
		var d := DayState.new()
		d.day = out.size()
		d.energy_min_j = energy_j[first]
		for i in range(first, last + 1):
			d.energy_min_j = minf(d.energy_min_j, energy_j[i])
			if mode[i] == Mode.SAFE:
				d.safe_time_s += dt_s
		d.energy_end_j = energy_j[last]
		d.stored_bits_end = stored_bits[last]
		d.delivered_bits = delivered_bits[last] - prev_delivered
		d.discarded_bits = discarded_bits[last] - prev_discarded
		d.mode_end = mode[last]
		prev_delivered = delivered_bits[last]
		prev_discarded = discarded_bits[last]
		var day_end_s := (last + 1) * dt_s
		while ev < events.size() and float(events[ev]["t_s"]) < day_end_s:
			d.events.append(events[ev])
			ev += 1
		out.append(d)
		first = last + 1
	return out

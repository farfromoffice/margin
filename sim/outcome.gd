class_name Outcome
extends RefCounted
## Reads a finished run the way the report does: what held the mission back and
## whether the scenario goals were met. Kept out of the UI so it can be tested.

const FACTORS: Array[StringName] = [&"power", &"storage", &"downlink"]
## a backlog above this share of everything generated counts as downlink limited
const DOWNLINK_BACKLOG_SHARE := 0.1
const BITS_PER_MB := 8.0e6


## Which of FACTORS actually bit during the run. Empty means nothing did.
static func limiting_factors(r: RunResult) -> Array[StringName]:
	var out: Array[StringName] = []
	if r.end_reason == RunResult.EndReason.POWER_LOST or r.safe_time_s > 0.0:
		out.append(&"power")
	if r.discarded_bits_total > 0.0:
		out.append(&"storage")
	var backlog := r.discarded_bits_total + r.stored_bits_end
	if r.generated_bits_total > 0.0 and backlog > DOWNLINK_BACKLOG_SHARE * r.generated_bits_total:
		out.append(&"downlink")
	return out


## factor_numbers returns the numbers behind the limiting factors of a flown run:
## what the camera made per day on average, what the radio could send per day
## with the passes this orbit and these stations give, the pass time per day, the
## energy per orbit at the launch settings and the memory size. The report uses
## them to explain a factor with the design's own figures.
static func factor_numbers(r: RunResult, input: SimInput, timeline: OrbitTimeline) -> Dictionary:
	var days := maxf(r.end_t_s / 86400.0, 1.0 / 24.0)
	return {
		"made_per_day": r.generated_bits_total / days,
		"sendable_per_day": Warnings.deliverable_bits_per_day(input, timeline),
		"contact_s_per_day": timeline.contact_s_per_day(),
		"energy_per_orbit_j": Warnings.orbit_energy_j(input, timeline),
		"storage_bits": input.storage_capacity_bits,
	}


## One row per scenario goal: {id, target, actual, met}. Goals the game can't
## measure yet come back with actual null and met false.
static func objectives(scenario: Scenario, r: RunResult) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in scenario.objectives:
		var target: float = scenario.objectives[id]
		var actual: Variant = null
		match id:
			&"delivered_mb":
				actual = r.delivered_bits_total / BITS_PER_MB
		var met := actual != null and r.end_reason == RunResult.EndReason.COMPLETED and float(actual) >= target
		out.append({"id": id, "target": target, "actual": actual, "met": met})
	return out


static func compare_runs(operated: RunResult, baseline: RunResult, scenario: Scenario) -> Dictionary:
	return {
		"intervened": not operated.commands.is_empty(),
		"delivered_bits": _metric(operated.delivered_bits_total, baseline.delivered_bits_total, BITS_PER_MB),
		"discarded_bits": _metric(operated.discarded_bits_total, baseline.discarded_bits_total, BITS_PER_MB),
		"safe_time_s": _metric(operated.safe_time_s, baseline.safe_time_s, 60.0),
		"completed": {
			"operated": operated.end_reason == RunResult.EndReason.COMPLETED,
			"baseline": baseline.end_reason == RunResult.EndReason.COMPLETED,
		},
		"objectives_met": {
			"operated": _all_met(scenario, operated),
			"baseline": _all_met(scenario, baseline),
		},
	}


static func _metric(operated: float, baseline: float, floor_value: float) -> Dictionary:
	var diff := operated - baseline
	var threshold := maxf(floor_value, 0.001 * absf(baseline))
	var verdict := &"same"
	if diff > threshold:
		verdict = &"more"
	elif diff < -threshold:
		verdict = &"less"
	return {"operated": operated, "baseline": baseline, "diff": diff, "verdict": verdict}


## _all_met returns true when every scenario goal was met. A scenario without goals
## returns false.
static func _all_met(scenario: Scenario, r: RunResult) -> bool:
	var rows := objectives(scenario, r)
	return not rows.is_empty() and rows.all(func(row): return row["met"])


## Splits a prediction into what was right, what was missed and what never happened.
static func compare_prediction(predicted: Array[StringName], actual: Array[StringName]) -> Dictionary:
	var hit: Array[StringName] = []
	var missed: Array[StringName] = []
	var wrong: Array[StringName] = []
	for f in actual:
		if f in predicted:
			hit.append(f)
		else:
			missed.append(f)
	for f in predicted:
		if not f in actual:
			wrong.append(f)
	return {"hit": hit, "missed": missed, "wrong": wrong}

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

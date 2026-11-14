class_name FailurePlan
extends RefCounted
## Draws which failures strike a mission and when, once, before launch. The
## simulator only replays the plan, so a run with the same seed and the same
## commands stays identical, and the baseline meets the same failures.

## Teaching values: every mission meets at least one failure, so there is always
## something to manage, and never so many that the design stops mattering.
const MIN_FAILURES := 1
const MAX_FAILURES := 3
## Nothing strikes in the first or last tenth, there would be no time to react
## or nothing left to lose.
const WINDOW_START := 0.1
const WINDOW_END := 0.9


## Returns [{t_s, kind, magnitude}] sorted by t_s. entries are failures.json rows;
## each kind strikes at most once. t_s sits on a step boundary.
static func generate(seed: int, duration_s: float, dt_s: float, entries: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if entries.is_empty() or duration_s <= 0.0 or dt_s <= 0.0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# hmm, sort by id first, Catalog.all() comes from a Dictionary and the order
	# must not depend on load order or the same seed draws different failures
	var pool := entries.duplicate()
	pool.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	var count := mini(rng.randi_range(MIN_FAILURES, MAX_FAILURES), pool.size())
	var steps := int(duration_s / dt_s)
	for n in count:
		var e: Dictionary = _pick(rng, pool)
		pool.erase(e)
		var step := rng.randi_range(int(steps * WINDOW_START), int(steps * WINDOW_END))
		var lo := float(e.get("magnitude_min", 0.0))
		var hi := float(e.get("magnitude_max", lo))
		out.append({"t_s": step * dt_s, "kind": StringName(str(e["id"])), "magnitude": rng.randf_range(lo, hi)})
	out.sort_custom(func(a, b): return a["t_s"] < b["t_s"])
	return out


static func _pick(rng: RandomNumberGenerator, pool: Array) -> Dictionary:
	var total := 0.0
	for e in pool:
		total += maxf(float(e["weight"]), 0.0)
	var roll := rng.randf() * total
	for e in pool:
		roll -= maxf(float(e["weight"]), 0.0)
		if roll < 0.0:
			return e
	return pool.back()

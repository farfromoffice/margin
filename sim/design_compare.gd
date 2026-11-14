class_name DesignCompare
extends RefCounted
## Lines up two designs choice by choice so the report can show the last flight
## and this one side by side. Values are catalog names and plain numbers, the UI
## formats them.

## row order on screen; parts first, then the totals the limits care about
const PART_ROWS: Array[String] = ["orbit", "launcher", "structure", "solar", "battery", "comms", "adcs", "instrument"]


## One row per choice: {key, before, after, changed}. Part rows hold names ("" for
## nothing picked), ground_station holds a list of names, duty_cycle, mass_kg and
## cost_kusd hold floats. catalog only needs get_entry(table, id).
static func rows(before: MissionDesign, after: MissionDesign, catalog: Object) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in PART_ROWS:
		out.append(_row(key, _choice(before, key, catalog), _choice(after, key, catalog)))
	out.append(_row("ground_station", _station_names(before, catalog), _station_names(after, catalog)))
	out.append(_row("duty_cycle", before.instrument_duty_cycle, after.instrument_duty_cycle))
	var a := LaunchCheck.totals(before, catalog)
	var b := LaunchCheck.totals(after, catalog)
	out.append(_row("mass_kg", a["mass_kg"], b["mass_kg"]))
	out.append(_row("cost_kusd", a["cost_kusd"], b["cost_kusd"]))
	return out


## How many choices differ, mass and cost left out since they only follow the parts.
static func changed_count(rows_: Array[Dictionary]) -> int:
	return rows_.filter(func(r): return r["changed"] and not r["key"] in ["mass_kg", "cost_kusd"]).size()


static func _row(key: String, before: Variant, after: Variant) -> Dictionary:
	var changed: bool
	if before is float:
		# yeah, float sums of the same parts in another order can drift in the last bit
		changed = not is_equal_approx(before, after)
	else:
		changed = before != after
	return {"key": key, "before": before, "after": after, "changed": changed}


static func _choice(d: MissionDesign, key: String, catalog: Object) -> String:
	match key:
		"orbit":
			return _name(catalog.get_entry("orbits", d.orbit_id))
		"launcher":
			return _name(catalog.get_entry("launchers", d.launcher_id))
	var names: Array[String] = []
	for id in d.component_ids:
		var c: Dictionary = catalog.get_entry("components", id)
		if str(c.get("category", "")) == key:
			names.append(_name(c))
	return ", ".join(names)


static func _station_names(d: MissionDesign, catalog: Object) -> Array[String]:
	var out: Array[String] = []
	for id in d.ground_station_ids:
		out.append(_name(catalog.get_entry("ground_stations", id)))
	out.sort()
	return out


static func _name(entry: Dictionary) -> String:
	return str(entry.get("name", entry.get("id", "")))

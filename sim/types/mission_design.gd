class_name MissionDesign
extends RefCounted
## Everything the players decided before launch. Only ids live here, the actual
## numbers come from Catalog, so a saved design stays small and shareable.

var scenario_id: StringName = &""
## requirement id -> chosen level, e.g. {&"resolution_m": 30.0}. Always float:
## JSON has no int. Anything else would change type on save and load.
var requirements: Dictionary[StringName, float] = {}
var launcher_id: StringName = &""
var orbit_id: StringName = &""
## bus parts (structure, power, battery, comms, obc, adcs, propulsion)
var component_ids: Array[StringName] = []
var instrument_ids: Array[StringName] = []
var ground_station_ids: Array[StringName] = []
## share of each step the instrument is on, 0..1. Averaged over every step,
## not tied to sunlight.
var instrument_duty_cycle := 1.0


func to_dict() -> Dictionary:
	return {
		"scenario_id": String(scenario_id),
		"requirements": requirements.duplicate(true),
		"launcher_id": String(launcher_id),
		"orbit_id": String(orbit_id),
		"component_ids": _to_strings(component_ids),
		"instrument_ids": _to_strings(instrument_ids),
		"ground_station_ids": _to_strings(ground_station_ids),
		"instrument_duty_cycle": instrument_duty_cycle,
	}


## Builds a design from an imported dict. Unknown or wrongly typed fields are
## dropped instead of crashing, since this comes from whatever a player pasted.
static func from_dict(d: Dictionary) -> MissionDesign:
	var out := MissionDesign.new()
	out.scenario_id = StringName(str(d.get("scenario_id", "")))
	out.requirements = _to_levels(d.get("requirements", {}))
	out.launcher_id = StringName(str(d.get("launcher_id", "")))
	out.orbit_id = StringName(str(d.get("orbit_id", "")))
	out.component_ids = _to_names(d.get("component_ids", []))
	out.instrument_ids = _to_names(d.get("instrument_ids", []))
	out.ground_station_ids = _to_names(d.get("ground_station_ids", []))
	# older saves have no duty cycle, those ran the instrument all the time
	var duty: Variant = d.get("instrument_duty_cycle", 1.0)
	out.instrument_duty_cycle = clampf(float(duty), 0.0, 1.0) if (duty is int or duty is float) else 1.0
	return out


static func _to_strings(ids: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for id in ids:
		out.append(String(id))
	return out


static func _to_names(value: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if value is Array:
		for v in value:
			if v is String or v is StringName:
				out.append(StringName(v))
	return out


## Non numeric values are dropped, same as bad ids above.
static func _to_levels(value: Variant) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	if value is Dictionary:
		for k in value:
			var v: Variant = value[k]
			if v is int or v is float:
				out[StringName(str(k))] = float(v)
	return out

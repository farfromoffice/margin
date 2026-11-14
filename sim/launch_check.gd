class_name LaunchCheck
extends RefCounted
## Hard limits checked before launch. Any violation blocks it.
## Each violation is {kind, value, limit, unit}; value and limit are null when
## there is no number to show (missing parts, unknown orbit).

## without one of these the run means nothing, so they block like any limit
const REQUIRED_CATEGORIES: Array[String] = ["structure", "solar", "battery", "comms", "obc", "instrument"]


## catalog only needs get_entry(table, id). Budget counts hardware plus launcher;
## ground station pass costs are not in it.
static func check(design: MissionDesign, scenario: Scenario, catalog: Object) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sums := totals(design, catalog)
	var mass_kg: float = sums["mass_kg"]
	var cost_kusd: float = sums["cost_kusd"]
	var seen := {}
	var structure := {}
	for id in design.component_ids:
		var c: Dictionary = catalog.get_entry("components", id)
		if c.is_empty():
			out.append(_v(&"unknown_component", String(id), null, ""))
			continue
		seen[str(c.get("category", ""))] = true
		if c.get("category", "") == "structure":
			structure = c
	for category in REQUIRED_CATEGORIES:
		if not seen.has(category):
			out.append(_v(&"missing_part", category, null, ""))
	if design.ground_station_ids.is_empty():
		out.append(_v(&"missing_part", "ground_station", null, ""))
	# max_payload_kg is what the frame carries on top of its own mass
	if structure.has("max_payload_kg"):
		var payload_kg := mass_kg - float(structure.get("mass_kg", 0.0))
		if payload_kg > float(structure["max_payload_kg"]):
			out.append(_v(&"over_structure_payload", payload_kg, float(structure["max_payload_kg"]), "kg"))

	if not scenario.allowed_orbit_ids.is_empty() and not design.orbit_id in scenario.allowed_orbit_ids:
		out.append(_v(&"orbit_not_allowed", String(design.orbit_id), null, ""))

	var launcher: Dictionary = catalog.get_entry("launchers", design.launcher_id)
	if launcher.is_empty():
		out.append(_v(&"missing_part", "launcher", null, ""))
	else:
		var capacity: Variant = launcher.get("capacity_kg", {})
		var limit: Variant = capacity.get(String(design.orbit_id)) if capacity is Dictionary else null
		if not (limit is int or limit is float):
			out.append(_v(&"orbit_unreachable", String(design.orbit_id), null, ""))
		elif mass_kg > float(limit):
			out.append(_v(&"over_launcher_capacity", mass_kg, float(limit), "kg"))

	# 0 means no limit, the sandbox uses that
	if scenario.max_mass_kg > 0.0 and mass_kg > scenario.max_mass_kg:
		out.append(_v(&"over_scenario_mass", mass_kg, scenario.max_mass_kg, "kg"))
	if scenario.budget_kusd > 0.0 and cost_kusd > scenario.budget_kusd:
		out.append(_v(&"over_budget", cost_kusd, scenario.budget_kusd, "kusd"))
	return out


## Mass of every part and cost of parts plus launcher, the numbers the limits
## above are checked against. The design screen shows them live.
static func totals(design: MissionDesign, catalog: Object) -> Dictionary:
	var mass_kg := 0.0
	var cost_kusd := 0.0
	for id in design.component_ids:
		var c: Dictionary = catalog.get_entry("components", id)
		mass_kg += float(c.get("mass_kg", 0.0))
		cost_kusd += float(c.get("cost_kusd", 0.0))
	cost_kusd += float(catalog.get_entry("launchers", design.launcher_id).get("cost_kusd", 0.0))
	return {"mass_kg": mass_kg, "cost_kusd": cost_kusd}


static func _v(kind: StringName, value: Variant, limit: Variant, unit: String) -> Dictionary:
	return {"kind": kind, "value": value, "limit": limit, "unit": unit}

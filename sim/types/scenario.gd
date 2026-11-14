class_name Scenario
extends RefCounted
## One mission card: what the players are asked to do and under which limits.
## Loaded from data/scenarios.json by Catalog.

var id: StringName = &""
var title := ""
var briefing := ""
## 1 easy .. 3 hard, also picks the component tier shown in the catalog
var difficulty := 1
var duration_days := 0
var budget_kusd := 0.0
var max_mass_kg := 0.0
var allowed_orbit_ids: Array[StringName] = []
## the resources the UI should highlight for this mission
var critical_resources: Array[StringName] = []
## goal id -> threshold, e.g. {&"science": 100, &"data_downlinked_mb": 5000}
var objectives: Dictionary = {}
var sandbox := false


static func from_dict(d: Dictionary) -> Scenario:
	var s := Scenario.new()
	s.id = StringName(str(d.get("id", "")))
	s.title = str(d.get("title", ""))
	s.briefing = str(d.get("briefing", ""))
	s.difficulty = clampi(int(d.get("difficulty", 1)), 1, 3)
	s.duration_days = maxi(int(d.get("duration_days", 0)), 0)
	s.budget_kusd = maxf(float(d.get("budget_kusd", 0.0)), 0.0)
	s.max_mass_kg = maxf(float(d.get("max_mass_kg", 0.0)), 0.0)
	s.allowed_orbit_ids = _to_names(d.get("allowed_orbit_ids", []))
	s.critical_resources = _to_names(d.get("critical_resources", []))
	var obj: Variant = d.get("objectives", {})
	if obj is Dictionary:
		s.objectives = obj.duplicate(true)
	s.sandbox = bool(d.get("sandbox", false))
	return s


static func _to_names(value: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if value is Array:
		for v in value:
			out.append(StringName(str(v)))
	return out

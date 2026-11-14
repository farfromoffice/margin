extends Node
## Read only view of everything in data/*.json. Load once at startup, then ask
## by id. Bad entries get skipped with a warning so one typo doesn't kill the game.

const DATA_DIR := "res://data/"

const REQUIRED := {
	"components": ["id", "name", "category", "tier", "mass_kg", "power_w", "cost_kusd"],
	"launchers": ["id", "name", "cost_kusd", "capacity_kg"],
	"orbits": ["id", "name", "body"],
	"scenarios": ["id", "title", "duration_days"],
	"ground_stations": ["id", "name", "network"],
	"real_missions": ["id", "name", "orbit_id"],
}

## table name -> { id (StringName) -> Dictionary }
var _tables: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	_tables.clear()
	for table in REQUIRED:
		_tables[table] = _load_table(table)


func get_entry(table: String, id: StringName) -> Dictionary:
	return _tables.get(table, {}).get(id, {})


func all(table: String) -> Array:
	return _tables.get(table, {}).values()


func components_in(category: String) -> Array:
	return all("components").filter(func(c): return c["category"] == category)


func get_scenario(id: StringName) -> Scenario:
	var d := get_entry("scenarios", id)
	return Scenario.from_dict(d) if not d.is_empty() else null


func _load_table(table: String) -> Dictionary:
	var out := {}
	var path := DATA_DIR + table + ".json"
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_warning("Catalog: %s is missing or empty" % path)
		return out
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Array:
		push_error("Catalog: %s must be a JSON array" % path)
		return out
	for entry in parsed:
		if not entry is Dictionary:
			push_warning("Catalog: non object entry in %s skipped" % path)
			continue
		var missing: Array = REQUIRED[table].filter(func(k): return not entry.has(k))
		if not missing.is_empty():
			push_warning("Catalog: %s entry %s missing %s, skipped" % [table, entry.get("id", "?"), missing])
			continue
		var id := StringName(str(entry["id"]))
		if out.has(id):
			push_warning("Catalog: duplicate id %s in %s, keeping the first" % [id, table])
			continue
		out[id] = entry
	return out

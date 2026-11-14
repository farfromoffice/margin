extends Node
## Read only view of everything in data/*.json. Load once at startup, then ask
## by id. Bad entries get skipped with a warning so one typo doesn't kill the game.
## Fields with a non SI suffix (capacity_wh, altitude_km, ...) also get an SI twin
## at load, so the sim only ever reads SI.

const DATA_DIR := "res://data/"

const REQUIRED := {
	"components": ["id", "name", "category", "tier", "mass_kg", "power_w", "safe_power_w", "cost_kusd", "source", "provenance"],
	"launchers": ["id", "name", "cost_kusd", "capacity_kg", "source", "provenance"],
	"orbits": ["id", "name", "body", "source", "provenance"],
	"scenarios": ["id", "title", "duration_days"],
	"ground_stations": ["id", "name", "network", "source", "provenance"],
	"real_missions": ["id", "name", "orbit_id"],
}

const PROVENANCE: Array[String] = ["documented", "approximation", "fictional"]

## non SI suffix -> [SI suffix, factor]. Longest suffix wins, so _mbps never
## gets mistaken for _mb.
const TO_SI := {
	"_wh": ["_j", 3600.0],
	"_km": ["_m", 1000.0],
	"_days": ["_s", 86400.0],
	"_bytes": ["_bits", 8.0],
	"_mb": ["_bits", 8.0e6],
	"_kbps": ["_bps", 1.0e3],
	"_mbps": ["_bps", 1.0e6],
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


## Adds an SI twin for every top level numeric field with a known non SI suffix.
## The original stays, the UI shows it. Nested values (capacity_kg, contacts_s)
## are left alone, they are SI already.
static func add_si_fields(entry: Dictionary) -> void:
	for key in entry.keys():
		var v: Variant = entry[key]
		if not (v is int or v is float):
			continue
		var suffix := _non_si_suffix(String(key))
		if suffix.is_empty():
			continue
		var rule: Array = TO_SI[suffix]
		var si_key := String(key).trim_suffix(suffix) + String(rule[0])
		entry[si_key] = float(v) * float(rule[1])


static func _non_si_suffix(key: String) -> String:
	var best := ""
	for suffix: String in TO_SI:
		if key.ends_with(suffix) and suffix.length() > best.length():
			best = suffix
	return best


static func provenance_error(entry: Dictionary) -> String:
	if entry.has("provenance") and not str(entry["provenance"]) in PROVENANCE:
		return "has unknown provenance %s" % entry["provenance"]
	var fields: Variant = entry.get("provenance_fields", {})
	if not fields is Dictionary:
		return "has provenance_fields that is not an object"
	for field in fields:
		if not str(fields[field]) in PROVENANCE:
			return "has unknown provenance %s for %s" % [fields[field], field]
	return ""


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
		var bad_label := provenance_error(entry)
		if not bad_label.is_empty():
			push_warning("Catalog: %s entry %s %s, skipped" % [table, entry["id"], bad_label])
			continue
		var id := StringName(str(entry["id"]))
		if out.has(id):
			push_warning("Catalog: duplicate id %s in %s, keeping the first" % [id, table])
			continue
		add_si_fields(entry)
		out[id] = entry
	return out

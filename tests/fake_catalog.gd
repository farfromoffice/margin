extends RefCounted
## Stand in for the Catalog autoload: same get_entry() shape, tables filled by
## the test. SI twins are added the same way the real one does it.

var tables := {}


func add(table: String, entry: Dictionary) -> void:
	var e := entry.duplicate(true)
	Catalog.add_si_fields(e)
	if not tables.has(table):
		tables[table] = {}
	tables[table][StringName(str(e["id"]))] = e


func get_entry(table: String, id: StringName) -> Dictionary:
	return tables.get(table, {}).get(id, {})

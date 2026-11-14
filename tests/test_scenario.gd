extends GutTest


func test_values_are_clamped() -> void:
	var s := Scenario.from_dict({"id": "x", "difficulty": 9, "duration_days": -5, "budget_kusd": -1})
	assert_eq(s.difficulty, 3)
	assert_eq(s.duration_days, 0)
	assert_eq(s.budget_kusd, 0.0)


func test_objective_thresholds_become_float() -> void:
	var s := Scenario.from_dict({"id": "x", "objectives": {"science": 100, "label": "x"}})
	assert_eq(s.objectives.keys(), [&"science"])
	assert_typeof(s.objectives[&"science"], TYPE_FLOAT)


func test_catalog_has_sandbox() -> void:
	var s := Catalog.get_scenario(&"sandbox")
	assert_not_null(s)
	assert_true(s.sandbox)

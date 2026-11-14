extends SceneTree
## Flies every Wildfire Watch design that passes the launch check, no failures and
## nobody at the controls, and prints one CSV row per design. The balance table in
## RESEARCH.md comes from this.
##
## godot --headless -s tools/balance.gd > balance.csv
## The full sweep takes most of an hour on one core. Pass a shard to split it,
## e.g. `-- 3/12` runs every twelfth design starting at the fourth; the header
## only comes out of shard 0.
## `-- count` flies nothing and prints how many candidate designs each launch check
## rules out, one design per camera setting, overlaps counted for every check.

const SCENARIO := &"wildfire_watch"
const DUTIES: Array[float] = [0.1, 0.25, 0.5, 1.0]

var _started := false
var _shard := 0
var _shards := 1
var _n := 0
var _count := false
## launch check kind (or "launchable") -> designs, for -- count
var _tally := {}


func _process(_delta: float) -> bool:
	# hmm, autoloads are only in the tree once the loop runs, not in _initialize
	if _started:
		return true
	_started = true
	var args := OS.get_cmdline_user_args()
	_count = args.has("count")
	if not args.is_empty() and args[0].contains("/"):
		var parts := args[0].split("/")
		_shards = maxi(1, parts[1].to_int())
		_shard = clampi(parts[0].to_int(), 0, _shards - 1)
	_sweep(root.get_node("Catalog"))
	return true


func _sweep(catalog: Node) -> void:
	var scenario: Scenario = catalog.get_scenario(SCENARIO)
	var stations := _subsets(catalog.all("ground_stations").map(func(g): return StringName(g["id"])))
	if _shard == 0 and not _count:
		print("structure,solar,battery,radio,adcs,camera,stations,launcher,orbit,duty,cost_kusd,mass_kg,end,delivered_mb,discarded_mb,missed_mb,safe_h,factors,goal")
	for structure in _ids(catalog, "structure"):
		for solar in _ids(catalog, "solar"):
			for battery in _ids(catalog, "battery"):
				for radio in _ids(catalog, "comms"):
					# adcs is optional on the design screen, so &"" stands for flying without one
					for adcs in [&""] + _ids(catalog, "adcs"):
						for camera in _ids(catalog, "instrument"):
							for launcher in catalog.all("launchers"):
								for orbit_id in launcher["capacity_kg"]:
									for st in stations:
										for duty in DUTIES:
											var d := MissionDesign.new()
											d.scenario_id = SCENARIO
											d.component_ids = [structure, solar, battery, radio, &"obc_32gb", camera]
											if adcs != &"":
												d.component_ids.append(adcs)
											d.ground_station_ids = st
											d.launcher_id = StringName(launcher["id"])
											d.orbit_id = StringName(orbit_id)
											d.instrument_duty_cycle = duty
											if not LaunchCheck.check(d, scenario, catalog).is_empty():
												continue
											_n += 1
											if _n % _shards != _shard:
												continue
											_fly(d, scenario, catalog)
	if _count:
		for k in _tally:
			print("%s,%d" % [k, _tally[k]])
	quit()


## _add counts a candidate once under each distinct check it fails or as launchable.
func _add(violations: Array[Dictionary]) -> void:
	var kinds := {}
	for v in violations:
		kinds[String(v["kind"])] = true
	if kinds.is_empty():
		kinds["launchable"] = true
	kinds["candidates"] = true
	for k in kinds:
		_tally[k] = _tally.get(k, 0) + 1


func _fly(d: MissionDesign, scenario: Scenario, catalog: Node) -> void:
	var input := SimInput.from_design(d, scenario, catalog)
	var timeline := OrbitTimeline.build(catalog.get_entry("orbits", d.orbit_id), d.ground_station_ids, input.duration_s)
	var r := Simulator.run(input, timeline)
	var sums := LaunchCheck.totals(d, catalog)
	var met := Outcome.objectives(scenario, r).all(func(row): return row["met"])
	var c := d.component_ids
	var adcs: StringName = c[6] if c.size() > 6 else &""
	print(",".join([c[0], c[1], c[2], c[3], adcs, c[5], "+".join(d.ground_station_ids), d.launcher_id, d.orbit_id,
		d.instrument_duty_cycle, sums["cost_kusd"], snappedf(sums["mass_kg"], 0.01),
		"done" if r.end_reason == RunResult.EndReason.COMPLETED else "lost",
		roundi(r.delivered_bits_total / 8e6), roundi(r.discarded_bits_total / 8e6), roundi(r.missed_bits_total / 8e6),
		snappedf(r.safe_time_s / 3600.0, 0.1), "+".join(Outcome.limiting_factors(r)), met]))


func _ids(catalog: Node, category: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for c in catalog.components_in(category):
		out.append(StringName(c["id"]))
	return out


## every non empty subset, small enough to brute force with three stations
func _subsets(ids: Array) -> Array:
	var out: Array = []
	for mask in range(1, 1 << ids.size()):
		var s: Array[StringName] = []
		for i in ids.size():
			if mask & (1 << i):
				s.append(ids[i])
		out.append(s)
	return out

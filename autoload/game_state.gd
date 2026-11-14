extends Node
## The one place that knows what mission is being played right now.
## Screens read from here, mutate `design`, then call touch_design() so EventBus fires.

const ROLES: Array[StringName] = [&"lead", &"spacecraft", &"ground", &"launch"]

var scenario_id: StringName = &""
var design := MissionDesign.new()
## role -> player index; with one player everything points at 0
var role_owner: Dictionary = {}
var player_count := 1
## hmm, keep the seed here so a replay with the same design gives the same run
var run_seed := 0
## limiting factors the players expect, from Outcome.FACTORS; empty means "none"
var prediction: Array[StringName] = []
var last_input: SimInput
var last_warnings: Array[Dictionary] = []
var last_result: RunResult
## the run before last_result, so the report can say whether the redesign helped
var previous_result: RunResult
## The designs that flew last_result and previous_result. Copies, since the
## design screen keeps editing `design` in place.
var last_design: MissionDesign
var previous_design: MissionDesign
## The mission flown on the operations screen. It is null before launch.
var mission: Mission
## Whether start_mission draws a failure plan. The same seed gives the same
## failures, so a redesign meets them again at the same times.
var live_failures := true
## The design of last_result flown with its launch settings and no player changes.
var baseline_result: RunResult


func new_mission(p_scenario_id: StringName, p_player_count: int) -> void:
	scenario_id = p_scenario_id
	player_count = clampi(p_player_count, 1, 4)
	design = MissionDesign.new()
	design.scenario_id = scenario_id
	run_seed = randi()
	prediction.clear()
	last_input = null
	last_warnings.clear()
	last_result = null
	previous_result = null
	last_design = null
	previous_design = null
	mission = null
	baseline_result = null
	role_owner.clear()
	for i in ROLES.size():
		role_owner[ROLES[i]] = i % player_count
	EventBus.design_changed.emit()


## Call after mutating `design` so every screen redraws its margins.
func touch_design() -> void:
	EventBus.design_changed.emit()


func scenario() -> Scenario:
	return Catalog.get_scenario(scenario_id)


## start_mission builds the SimInput and the orbit timeline for the current design
## and returns a Mission for the operations screen to fly. The caller runs the
## launch check before.
func start_mission() -> Mission:
	var input := SimInput.from_design(design, scenario(), Catalog)
	var orbit := Catalog.get_entry("orbits", design.orbit_id)
	var timeline := OrbitTimeline.build(orbit, design.ground_station_ids, input.duration_s)
	# Warnings.compute only reads timeline averages and does not move its cursors.
	# The mission can use the same timeline.
	last_warnings = Warnings.compute(input, timeline)
	last_input = input
	var failures: Array[Dictionary] = []
	if live_failures:
		failures = FailurePlan.generate(run_seed, input.duration_s, input.dt_s, Catalog.all("failures"))
	mission = Mission.new(input, timeline, failures)
	return mission


## finish_mission stores the result of the ended mission for the report and runs
## the baseline, the same design without player changes.
func finish_mission() -> void:
	assert(mission != null and mission.state.done, "GameState: finish_mission before the mission ended")
	previous_result = last_result
	last_result = mission.state.result
	previous_design = last_design
	last_design = MissionDesign.from_dict(design.to_dict())
	baseline_result = mission.baseline()


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
## the mission being flown on the operations screen, null before launch
var mission: Mission
## last_result's design flown with its launch settings and no intervention
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


## Launches the current design: locks its configuration and hands the
## operations screen a mission to fly. Launch check is the caller's job.
func start_mission() -> Mission:
	var input := SimInput.from_design(design, scenario(), Catalog)
	var orbit := Catalog.get_entry("orbits", design.orbit_id)
	var timeline := OrbitTimeline.build(orbit, design.ground_station_ids, input.duration_s)
	# warnings read the timeline's averages only, they leave its cursors alone
	last_warnings = Warnings.compute(input, timeline)
	last_input = input
	mission = Mission.new(input, timeline)
	return mission


## Call once the mission has ended: keeps the result for the report and flies
## the untouched design for comparison.
func finish_mission() -> void:
	assert(mission != null and mission.state.done, "GameState: finish_mission before the mission ended")
	previous_result = last_result
	last_result = mission.state.result
	baseline_result = mission.baseline()


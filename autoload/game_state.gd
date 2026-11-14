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


func new_mission(p_scenario_id: StringName, p_player_count: int) -> void:
	scenario_id = p_scenario_id
	player_count = clampi(p_player_count, 1, 4)
	design = MissionDesign.new()
	design.scenario_id = scenario_id
	run_seed = randi()
	role_owner.clear()
	for i in ROLES.size():
		role_owner[ROLES[i]] = i % player_count
	EventBus.design_changed.emit()


## Call after mutating `design` so every screen redraws its margins.
func touch_design() -> void:
	EventBus.design_changed.emit()

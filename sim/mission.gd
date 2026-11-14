class_name Mission
extends RefCounted

var input: SimInput
var timeline: OrbitTimeline
var controls: Controls
var state: SimState
var auto_pause := AutoPause.new()


func _init(p_input: SimInput, p_timeline: OrbitTimeline) -> void:
	input = p_input
	timeline = p_timeline
	controls = Controls.initial(input)
	state = Simulator.start(input)


## set_control changes a control between two steps and logs it with the current
## step time. Setting the value the control already has logs nothing.
func set_control(control: StringName, value: Variant) -> void:
	if state.done:
		return
	var before: Variant = controls.value_of(control)
	if not controls.apply(control, value):
		push_error("Mission: unknown control %s" % control)
		return
	var after: Variant = controls.value_of(control)
	if after == before:
		return
	state.result.commands.append({"t_s": state.t_s, "control": control, "value": after})
	if control == Controls.RADIO_ENABLED:
		auto_pause.rearm_contact()


## advance runs up to max_steps steps. It stops after the first step that fires an
## auto pause trigger and returns those triggers. It returns an empty array when
## no trigger fired.
func advance(max_steps: int) -> Array[StringName]:
	for k in max_steps:
		if state.done:
			break
		var mode_before := state.mode
		Simulator.step(state, input, controls, timeline)
		var fired := auto_pause.check(state, input, controls, mode_before)
		if not fired.is_empty():
			return fired
	return []


## finish runs the rest of the mission with the current controls and never pauses.
func finish() -> void:
	while not state.done:
		Simulator.step(state, input, controls, timeline)


## baseline runs the same SimInput again from the start with the launch settings
## and no player changes. The report compares it with the flown mission.
func baseline() -> RunResult:
	return Simulator.run(input, timeline.rewound())

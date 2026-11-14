class_name Mission
extends RefCounted

var input: SimInput
var timeline: OrbitTimeline
var controls: Controls
var state: SimState
var auto_pause := AutoPause.new()
var failures: Array[Dictionary] = []
## controls switched off by power_cycle(), switched back on after one step
var _cycling: Array[StringName] = []
var _cycle_back := {}


func _init(p_input: SimInput, p_timeline: OrbitTimeline, p_failures: Array[Dictionary] = []) -> void:
	input = p_input
	timeline = p_timeline
	failures = p_failures
	controls = Controls.initial(input)
	state = Simulator.start(input, failures)


## power_cycle switches the radio or the camera off for exactly one step and back
## on, which clears a hang. Both switches land in the command log like any other
## change, so the replay sees the same thing. The camera comes back at the duty
## cycle it had.
func power_cycle(control: StringName) -> void:
	if state.done or control in _cycling:
		return
	var back: Variant = controls.value_of(control)
	match control:
		Controls.RADIO_ENABLED:
			# an off radio is already cycling, it just comes back on after this step
			back = true
		Controls.DUTY_CYCLE:
			if float(back) <= 0.0:
				return
		_:
			push_error("Mission: cannot power-cycle %s" % control)
			return
	set_control(control, false if control == Controls.RADIO_ENABLED else 0.0)
	_cycle_back[control] = back
	_cycling.append(control)


## True while a power cycle of this control is under way.
func is_cycling(control: StringName) -> bool:
	return control in _cycling


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
		_finish_cycles()
		var fired := auto_pause.check(state, input, controls, mode_before)
		if not fired.is_empty():
			return fired
	return []


## finish runs the rest of the mission with the current controls and never pauses.
func finish() -> void:
	while not state.done:
		Simulator.step(state, input, controls, timeline)
		_finish_cycles()


## baseline runs the same SimInput again from the start with the launch settings,
## the same failures and no player changes, so nobody fixes anything. The report compares it with the flown mission.
func baseline() -> RunResult:
	return Simulator.run(input, timeline.rewound(), [], failures)


## design_alone runs the same SimInput with the launch settings, no failures and no
## player changes: what the design does on its own, the run a prediction made
## before launch can be held to.
func design_alone() -> RunResult:
	return Simulator.run(input, timeline.rewound(), [], [])


func _finish_cycles() -> void:
	if _cycling.is_empty() or state.done:
		return
	for control in _cycling:
		set_control(control, _cycle_back[control])
	_cycling.clear()
	_cycle_back.clear()

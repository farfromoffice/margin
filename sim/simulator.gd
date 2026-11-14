class_name Simulator
extends RefCounted
## Fixed step mission simulation, rules and their order are in DESIGN.md

## relative slack for the data bookkeeping check, sums of ~1e12 bits lose a few ulps
const INVARIANT_TOLERANCE := 1e-9


## failures is a FailurePlan, empty for a run where nothing breaks.
static func start(input: SimInput, failures: Array[Dictionary] = []) -> SimState:
	var s := SimState.new()
	var r := s.result
	s.failures = failures.duplicate(true)
	r.failures = failures.duplicate(true)
	r.dt_s = input.dt_s
	s.total_steps = int(ceil(input.duration_s / input.dt_s)) if input.dt_s > 0.0 else 0
	r.energy_j.resize(s.total_steps)
	r.stored_bits.resize(s.total_steps)
	r.delivered_bits.resize(s.total_steps)
	r.discarded_bits.resize(s.total_steps)
	r.mode.resize(s.total_steps)
	s.energy_j = minf(input.initial_energy_j, input.battery_capacity_j)
	if s.total_steps == 0:
		_finish(s, input)
	return s


## step advances the state by one step with the current controls and records the
## step in the result.
static func step(s: SimState, input: SimInput, controls: Controls, timeline: OrbitTimeline) -> void:
	assert(not s.done, "Simulator: step after the mission ended")
	var r := s.result
	var dt := input.dt_s
	var i := s.step
	var t := s.t_s
	var step_dt := minf(dt, input.duration_s - t)
	_strike_failures(s, input, t)
	var capacity := s.capacity_j(input)
	timeline.advance(t, step_dt)
	s.contact_starts = timeline.contact_starts
	# A radio that is switched off does not transmit and does not draw transmit power.
	# A hung one idles too, it just doesn't know it should be talking.
	var tx := timeline.contact_s if controls.radio_enabled and not s.radio_hung else 0.0
	# a power cycle needs one whole step with the part off, decided before the step runs
	var radio_cycled := s.radio_hung and not controls.radio_enabled
	var instrument_cycled := s.instrument_hung and (controls.duty_cycle <= 0.0 or s.mode == RunResult.Mode.SAFE)

	# 1. loads by the mode this step runs in
	var load_j: float
	if s.mode == RunResult.Mode.NORMAL:
		load_j = (input.bus_power_w + input.instrument_power_w * controls.duty_cycle) * step_dt \
				+ input.radio_tx_power_w * tx + input.radio_idle_power_w * (step_dt - tx)
	else:
		load_j = (input.bus_safe_power_w + input.radio_idle_power_w) * step_dt

	# 2. battery, surplus past full is simply lost
	var e := s.energy_j + input.solar_power_w * s.solar_health * timeline.sunlit_s - load_j
	if e < 0.0:
		s.energy_j = 0.0
		r.end_reason = RunResult.EndReason.POWER_LOST
		r.end_t_s = t + step_dt
		r.events.append({"t_s": r.end_t_s, "kind": &"power_lost", "energy_j": 0.0})
		_record(s, i)
		s.step = i + 1
		s.t_s = r.end_t_s
		r.energy_j.resize(s.step)
		r.stored_bits.resize(s.step)
		r.delivered_bits.resize(s.step)
		r.discarded_bits.resize(s.step)
		r.mode.resize(s.step)
		r.stored_bits_end = s.stored_bits
		s.done = true
		return
	s.energy_j = minf(e, capacity)

	# 4 to 6 use the mode the step ran in, the switch below lands next step
	var step_gen := input.instrument_rate_bps * controls.duty_cycle * dt * step_dt / dt
	if s.instrument_hung:
		# draws power like it is working, makes nothing. Not "missed": that is Safe mode's blame
		step_gen = 0.0
	if s.mode == RunResult.Mode.NORMAL:
		s.stored_bits += step_gen
		r.generated_bits_total += step_gen
		var d := minf(s.stored_bits, input.downlink_rate_bps * tx)
		s.stored_bits -= d
		r.delivered_bits_total += d
	else:
		r.missed_bits_total += step_gen
		r.safe_time_s += step_dt
	if radio_cycled:
		s.radio_hung = false
		r.events.append({"t_s": t + step_dt, "kind": &"recovered", "failure": &"radio_hang", "energy_j": s.energy_j})
	if instrument_cycled:
		s.instrument_hung = false
		r.events.append({"t_s": t + step_dt, "kind": &"recovered", "failure": &"instrument_hang", "energy_j": s.energy_j})
	if s.stored_bits > input.storage_capacity_bits:
		# newest data gets dropped, bookkeeping only
		r.discarded_bits_total += s.stored_bits - input.storage_capacity_bits
		s.stored_bits = input.storage_capacity_bits

	_record(s, i)

	# 3. mode change, effective next step
	if s.mode == RunResult.Mode.NORMAL and s.energy_j <= input.safe_enter_fraction * capacity:
		s.mode = RunResult.Mode.SAFE
		r.safe_entries += 1
		r.events.append({"t_s": t + step_dt, "kind": &"safe_enter", "energy_j": s.energy_j})
	elif s.mode == RunResult.Mode.SAFE and s.energy_j >= input.safe_exit_fraction * capacity:
		s.mode = RunResult.Mode.NORMAL
		r.events.append({"t_s": t + step_dt, "kind": &"safe_exit", "energy_j": s.energy_j})

	assert(_invariants_hold(s, input), "Simulator: invariant broken at step %d" % i)

	s.step = i + 1
	s.t_s = s.step * dt
	if s.step >= s.total_steps:
		_finish(s, input)


static func run(input: SimInput, timeline: OrbitTimeline, commands: Array[Dictionary] = [], failures: Array[Dictionary] = []) -> RunResult:
	var s := start(input, failures)
	var controls := Controls.initial(input)
	var next := 0
	while not s.done:
		while next < commands.size() and float(commands[next]["t_s"]) <= s.t_s:
			controls.apply(commands[next]["control"], commands[next]["value"])
			next += 1
		step(s, input, controls, timeline)
	s.result.commands = commands.duplicate(true)
	return s.result


## Applies every planned failure due at the start of this step. Fades stack on
## what is left, a second hit on a hung part changes nothing.
static func _strike_failures(s: SimState, input: SimInput, t: float) -> void:
	s.failures_started.clear()
	while s.next_failure < s.failures.size() and float(s.failures[s.next_failure]["t_s"]) <= t:
		var f: Dictionary = s.failures[s.next_failure]
		s.next_failure += 1
		var m := clampf(float(f.get("magnitude", 0.0)), 0.0, 1.0)
		match f["kind"]:
			&"battery_fade":
				s.battery_health *= 1.0 - m
				s.energy_j = minf(s.energy_j, s.capacity_j(input))
			&"solar_loss":
				s.solar_health *= 1.0 - m
			&"radio_hang":
				s.radio_hung = true
			&"instrument_hang":
				s.instrument_hung = true
			_:
				push_error("Simulator: unknown failure %s" % f["kind"])
				continue
		s.failures_started.append(f["kind"])
		s.result.events.append({"t_s": t, "kind": &"failure", "failure": f["kind"], "magnitude": m, "energy_j": s.energy_j})


static func _finish(s: SimState, input: SimInput) -> void:
	s.result.end_t_s = input.duration_s
	s.result.stored_bits_end = s.stored_bits
	s.done = true


static func _record(s: SimState, i: int) -> void:
	var r := s.result
	r.energy_j[i] = s.energy_j
	r.stored_bits[i] = s.stored_bits
	r.delivered_bits[i] = r.delivered_bits_total
	r.discarded_bits[i] = r.discarded_bits_total
	r.mode[i] = s.mode


## Only called inside assert(), so release builds skip it entirely.
static func _invariants_hold(s: SimState, input: SimInput) -> bool:
	var r := s.result
	var accounted := r.delivered_bits_total + r.discarded_bits_total + s.stored_bits
	var slack := INVARIANT_TOLERANCE * maxf(1.0, r.generated_bits_total)
	return absf(r.generated_bits_total - accounted) <= slack \
			and s.energy_j >= 0.0 and s.energy_j <= s.capacity_j(input) \
			and s.stored_bits >= 0.0 and s.stored_bits <= input.storage_capacity_bits

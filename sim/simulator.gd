class_name Simulator
extends RefCounted
## Fixed step mission simulation, rules and their order are in DESIGN.md
## ("Step rules"). Pure logic, no randomness: same input, same result.

## relative slack for the data bookkeeping check, sums of ~1e12 bits lose a few ulps
const INVARIANT_TOLERANCE := 1e-9


static func run(input: SimInput, timeline: OrbitTimeline) -> RunResult:
	var r := RunResult.new()
	r.dt_s = input.dt_s
	var dt := input.dt_s
	var steps := int(ceil(input.duration_s / dt)) if dt > 0.0 else 0
	r.energy_j.resize(steps)
	r.stored_bits.resize(steps)
	r.delivered_bits.resize(steps)
	r.discarded_bits.resize(steps)
	r.mode.resize(steps)

	var capacity := input.battery_capacity_j
	var energy := minf(input.initial_energy_j, capacity)
	var stored := 0.0
	var mode := RunResult.Mode.NORMAL
	var normal_load_w := input.bus_power_w + input.instrument_power_w * input.duty_cycle
	var safe_load_w := input.bus_safe_power_w + input.radio_idle_power_w
	var gen_per_step := input.instrument_rate_bps * input.duty_cycle * dt
	var done := steps

	for i in steps:
		var t := i * dt
		var step_dt := minf(dt, input.duration_s - t)
		timeline.advance(t, step_dt)
		var contact := timeline.contact_s

		# 1. loads by the mode this step runs in
		var load_j: float
		if mode == RunResult.Mode.NORMAL:
			load_j = normal_load_w * step_dt + input.radio_tx_power_w * contact \
					+ input.radio_idle_power_w * (step_dt - contact)
		else:
			load_j = safe_load_w * step_dt

		# 2. battery, surplus past full is simply lost
		var e := energy + input.solar_power_w * timeline.sunlit_s - load_j
		if e < 0.0:
			energy = 0.0
			r.end_reason = RunResult.EndReason.POWER_LOST
			r.end_t_s = t + step_dt
			r.events.append({"t_s": r.end_t_s, "kind": &"power_lost", "energy_j": 0.0})
			_record(r, i, energy, stored, mode)
			done = i + 1
			break
		energy = minf(e, capacity)

		# 4 to 6 use the mode the step ran in, the switch below lands next step
		var step_gen := gen_per_step * step_dt / dt
		if mode == RunResult.Mode.NORMAL:
			stored += step_gen
			r.generated_bits_total += step_gen
			var d := minf(stored, input.downlink_rate_bps * contact)
			stored -= d
			r.delivered_bits_total += d
		else:
			r.missed_bits_total += step_gen
			r.safe_time_s += step_dt
		if stored > input.storage_capacity_bits:
			# newest data gets dropped, bookkeeping only
			r.discarded_bits_total += stored - input.storage_capacity_bits
			stored = input.storage_capacity_bits

		_record(r, i, energy, stored, mode)

		# 3. mode change, effective next step
		if mode == RunResult.Mode.NORMAL and energy <= input.safe_enter_fraction * capacity:
			mode = RunResult.Mode.SAFE
			r.safe_entries += 1
			r.events.append({"t_s": t + step_dt, "kind": &"safe_enter", "energy_j": energy})
		elif mode == RunResult.Mode.SAFE and energy >= input.safe_exit_fraction * capacity:
			mode = RunResult.Mode.NORMAL
			r.events.append({"t_s": t + step_dt, "kind": &"safe_exit", "energy_j": energy})

		assert(_invariants_hold(r, stored, energy, input), "Simulator: invariant broken at step %d" % i)

	if done < steps:
		r.energy_j.resize(done)
		r.stored_bits.resize(done)
		r.delivered_bits.resize(done)
		r.discarded_bits.resize(done)
		r.mode.resize(done)
	else:
		r.end_t_s = input.duration_s
	r.stored_bits_end = stored
	return r


static func _record(r: RunResult, i: int, energy: float, stored: float, mode: int) -> void:
	r.energy_j[i] = energy
	r.stored_bits[i] = stored
	r.delivered_bits[i] = r.delivered_bits_total
	r.discarded_bits[i] = r.discarded_bits_total
	r.mode[i] = mode


## Only called inside assert(), so release builds skip it entirely.
static func _invariants_hold(r: RunResult, stored: float, energy: float, input: SimInput) -> bool:
	var accounted := r.delivered_bits_total + r.discarded_bits_total + stored
	var slack := INVARIANT_TOLERANCE * maxf(1.0, r.generated_bits_total)
	return absf(r.generated_bits_total - accounted) <= slack \
			and energy >= 0.0 and energy <= input.battery_capacity_j \
			and stored >= 0.0 and stored <= input.storage_capacity_bits

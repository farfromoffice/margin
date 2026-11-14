class_name Warnings
extends RefCounted
## Warnings estimates power and data from orbit and pass averages in Normal mode.
## compute lists the problems of a design before launch and never blocks it.
## forecast estimates the rest of a running mission with the current controls.
## Each warning is {kind, value, limit, unit}.


static func compute(input: SimInput, timeline: OrbitTimeline) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if timeline.period_s > 0.0:
		var net := orbit_energy_j(input, timeline)
		if net < 0.0:
			out.append(_w(&"orbit_energy_negative", net, 0.0, "J"))

	var generated_per_day := generated_bits_per_day(input)
	var deliverable_per_day := deliverable_bits_per_day(input, timeline)
	if generated_per_day > deliverable_per_day:
		out.append(_w(&"downlink_short", generated_per_day, deliverable_per_day, "bit"))
		var backlog_per_day := generated_per_day - deliverable_per_day
		var fill_s := input.storage_capacity_bits / backlog_per_day * 86400.0
		if fill_s < input.duration_s:
			out.append(_w(&"storage_fills", fill_s, input.duration_s, "s"))
	return out


static func forecast(input: SimInput, controls: Controls, timeline: OrbitTimeline, s: SimState) -> Dictionary:
	var net := orbit_energy_j(input, timeline, controls)
	var made := generated_bits_per_day(input, controls)
	var sendable := deliverable_bits_per_day(input, timeline, controls)
	var storage_full_in_s := INF
	if made > sendable:
		storage_full_in_s = maxf(input.storage_capacity_bits - s.stored_bits, 0.0) / (made - sendable) * 86400.0
	var safe_mode_in_s := INF
	if net < 0.0 and timeline.period_s > 0.0:
		var margin := s.energy_j - input.safe_enter_fraction * input.battery_capacity_j
		safe_mode_in_s = maxf(margin, 0.0) / -net * timeline.period_s
	return {
		"remaining_s": maxf(input.duration_s - s.t_s, 0.0),
		"energy_per_orbit_j": net,
		"generated_bits_per_day": made,
		"sendable_bits_per_day": sendable,
		"storage_full_in_s": storage_full_in_s,
		"safe_mode_in_s": safe_mode_in_s,
	}


## orbit_energy_j returns the Normal mode energy gained minus the energy spent over
## one average orbit. A negative value means the battery drains a little more every
## orbit. Without controls it uses the launch settings.
static func orbit_energy_j(input: SimInput, timeline: OrbitTimeline, controls: Controls = null) -> float:
	var c := controls if controls else Controls.initial(input)
	var period := timeline.period_s
	var contact_per_orbit := timeline.contact_s_per_day() * period / 86400.0 if c.radio_enabled else 0.0
	var gained := input.solar_power_w * (1.0 - timeline.eclipse_fraction) * period
	var spent := (input.bus_power_w + input.instrument_power_w * c.duty_cycle) * period \
			+ input.radio_tx_power_w * contact_per_orbit \
			+ input.radio_idle_power_w * (period - contact_per_orbit)
	return gained - spent


static func generated_bits_per_day(input: SimInput, controls: Controls = null) -> float:
	var c := controls if controls else Controls.initial(input)
	return input.instrument_rate_bps * c.duty_cycle * 86400.0


static func deliverable_bits_per_day(input: SimInput, timeline: OrbitTimeline, controls: Controls = null) -> float:
	var c := controls if controls else Controls.initial(input)
	return input.downlink_rate_bps * timeline.contact_s_per_day() if c.radio_enabled else 0.0


static func _w(kind: StringName, value: float, limit: float, unit: String) -> Dictionary:
	return {"kind": kind, "value": value, "limit": limit, "unit": unit}

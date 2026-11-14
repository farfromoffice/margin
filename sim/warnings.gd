class_name Warnings
extends RefCounted
## Back of the envelope checks before the run, all in Normal mode. They never
## block launch; the prediction screen and report compare them to the real run.
## Each warning is {kind, value, limit, unit}.


static func compute(input: SimInput, timeline: OrbitTimeline) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var period := timeline.period_s
	var contact_per_day := timeline.contact_s_per_day()

	if period > 0.0:
		var contact_per_orbit := contact_per_day * period / 86400.0
		var gained := input.solar_power_w * (1.0 - timeline.eclipse_fraction) * period
		var spent := (input.bus_power_w + input.instrument_power_w * input.duty_cycle) * period \
				+ input.radio_tx_power_w * contact_per_orbit \
				+ input.radio_idle_power_w * (period - contact_per_orbit)
		if gained - spent < 0.0:
			out.append(_w(&"orbit_energy_negative", gained - spent, 0.0, "J"))

	var generated_per_day := input.instrument_rate_bps * input.duty_cycle * 86400.0
	var deliverable_per_day := input.downlink_rate_bps * contact_per_day
	if generated_per_day > deliverable_per_day:
		out.append(_w(&"downlink_short", generated_per_day, deliverable_per_day, "bit"))
		var backlog_per_day := generated_per_day - deliverable_per_day
		var fill_s := input.storage_capacity_bits / backlog_per_day * 86400.0
		if fill_s < input.duration_s:
			out.append(_w(&"storage_fills", fill_s, input.duration_s, "s"))
	return out


static func _w(kind: StringName, value: float, limit: float, unit: String) -> Dictionary:
	return {"kind": kind, "value": value, "limit": limit, "unit": unit}

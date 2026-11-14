class_name Warnings
extends RefCounted
## Warnings estimates power and data from orbit and pass averages in Normal mode.
## compute lists the problems of a design before launch and never blocks it.
## forecast estimates the rest of a running mission with the current controls.
## Each warning is {kind, value, limit, unit}.


## the camera slider moves in these steps
const DUTY_STEP := 0.05


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
	input = _as_damaged(input, s)
	var c := _effective(controls, s)
	var net := orbit_energy_j(input, timeline, c)
	var made := 0.0 if s.instrument_hung else generated_bits_per_day(input, c)
	var sendable := deliverable_bits_per_day(input, timeline, c)
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


## projected_delivered_bits estimates the data at home when the mission ends if the
## controls stay as they are: what is home already and what the radio can still
## send, capped by what is stored and what the camera still makes. When the battery
## drains every orbit, the craft cycles between Normal and Safe mode after the first
## Safe mode: it drains from the exit level to the entry level in Normal and charges
## back across the same span in Safe, with the camera off and the radio silent. Both
## then only work for normal_share of the time.
static func projected_delivered_bits(input: SimInput, timeline: OrbitTimeline, controls: Controls, s: SimState) -> float:
	var f := forecast(input, controls, timeline, s)
	var remaining_days := float(f["remaining_s"]) / 86400.0
	var working_days := remaining_days
	var safe_s := float(f["safe_mode_in_s"])
	if s.mode == RunResult.Mode.SAFE:
		safe_s = 0.0
	if safe_s < float(f["remaining_s"]):
		var before := safe_s / 86400.0
		working_days = before + normal_share(input, timeline, float(f["energy_per_orbit_j"]), s) * (remaining_days - before)
	var made := float(f["generated_bits_per_day"]) * working_days
	var sendable := float(f["sendable_bits_per_day"]) * working_days
	return s.result.delivered_bits_total + minf(sendable, s.stored_bits + made)


## normal_share returns the share of time spent in Normal mode once the battery
## cycles through Safe mode. net is the Normal mode energy per orbit, negative when
## it drains. A Safe mode that cannot charge the battery gives 0.
static func normal_share(input: SimInput, timeline: OrbitTimeline, net: float, s: SimState) -> float:
	if net >= 0.0:
		return 1.0
	input = _as_damaged(input, s)
	var period := timeline.period_s
	var charge := input.solar_power_w * (1.0 - timeline.eclipse_fraction) * period \
			- (input.bus_safe_power_w + input.radio_idle_power_w) * period
	if charge <= 0.0:
		return 0.0
	return charge / (charge - net)


## choices lists the switches and repairs that answer an auto-pause, as
## {kind, value}: &"radio" switches the radio, &"restart" power-cycles the
## control named in value. The camera time is not among them on purpose: how far
## to turn it down trades data against power or memory, and that is the player's
## call, made on the slider with camera_step() and the effect lines to go by.
static func choices(fired: Array[StringName], input: SimInput, timeline: OrbitTimeline, controls: Controls, s: SimState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if AutoPause.FAILURE in fired:
		if s.radio_hung:
			out.append({"kind": &"restart", "value": Controls.RADIO_ENABLED})
		if s.instrument_hung and controls.duty_cycle > 0.0:
			out.append({"kind": &"restart", "value": Controls.DUTY_CYCLE})
	var f := forecast(input, controls, timeline, s)
	var power_short := float(f["energy_per_orbit_j"]) < 0.0
	if power_short and controls.radio_enabled and (AutoPause.LOW_BATTERY in fired or AutoPause.SAFE_ENTER in fired):
		out.append({"kind": &"radio", "value": false})
	# a locked radio comes back on with its restart, switching it on does nothing
	if (AutoPause.STORAGE_HIGH in fired or AutoPause.CONTACT_BEGIN in fired) and not controls.radio_enabled and not s.radio_hung:
		out.append({"kind": &"radio", "value": true})
	return out


## camera_step returns what 10 % of camera time is worth: the energy it uses per
## average orbit and the data it makes per day. The auto-pause panel shows it as
## the exchange rate between pictures and power or memory.
static func camera_step(input: SimInput, timeline: OrbitTimeline) -> Dictionary:
	return {
		"energy_per_orbit_j": input.instrument_power_w * 0.1 * timeline.period_s,
		"bits_per_day": input.instrument_rate_bps * 0.1 * 86400.0,
	}


## _effective copies the controls the way the spacecraft acts on them. A hung
## radio idles exactly like one switched off.
static func _effective(controls: Controls, s: SimState) -> Controls:
	var c := Controls.new()
	c.duty_cycle = controls.duty_cycle
	c.radio_enabled = controls.radio_enabled and not s.radio_hung
	return c


## Copy of input with the solar and battery numbers the failures so far left.
static func _as_damaged(input: SimInput, s: SimState) -> SimInput:
	if is_equal_approx(s.solar_health, 1.0) and is_equal_approx(s.battery_health, 1.0):
		return input
	var d := SimInput.new()
	for p in input.get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			d.set(p["name"], input.get(p["name"]))
	d.solar_power_w *= s.solar_health
	d.battery_capacity_j *= s.battery_health
	return d


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

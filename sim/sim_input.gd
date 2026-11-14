class_name SimInput
extends RefCounted
## Every number the simulator reads, resolved from ids to SI once before the run.
## Build it with from_design(), or fill the fields by hand in tests.

const DT_S := 60.0
## without a pointing system the camera faces the ground only part of the time.
const UNPOINTED_SHARE := 0.25

var duration_s := 0.0
var dt_s := DT_S
var solar_power_w := 0.0
var bus_power_w := 0.0
var bus_safe_power_w := 0.0
var instrument_power_w := 0.0
## useful pictures only, already cut to UNPOINTED_SHARE when nothing points the camera
var instrument_rate_bps := 0.0
## false when the design flies without a pointing system
var pointed := true
var duty_cycle := 1.0
var radio_tx_power_w := 0.0
var radio_idle_power_w := 0.0
var downlink_rate_bps := 0.0
var battery_capacity_j := 0.0
var safe_enter_fraction := 0.0
var safe_exit_fraction := 0.0
var storage_capacity_bits := 0.0
var initial_energy_j := 0.0


## catalog only needs get_entry(table, id), so tests can pass a stub.
## Unknown ids are skipped here; LaunchCheck is the one that complains.
static func from_design(design: MissionDesign, scenario: Scenario, catalog: Object) -> SimInput:
	var s := SimInput.new()
	s.duration_s = scenario.duration_s
	s.duty_cycle = clampf(design.instrument_duty_cycle, 0.0, 1.0)
	var battery_seen := false
	s.pointed = false
	for id in design.component_ids:
		var c: Dictionary = catalog.get_entry("components", id)
		if c.is_empty():
			continue
		match str(c.get("category", "")):
			"solar":
				# generated_w_1au is the Sun facing peak; sunlit_factor averages
				# pointing and cosine losses over a sunlit arc
				s.solar_power_w += float(c.get("generated_w_1au", 0.0)) * float(c.get("sunlit_factor", 1.0))
			"comms":
				# one radio on board; with two, powers add up and the faster one talks
				s.radio_tx_power_w += float(c.get("power_w", 0.0))
				s.radio_idle_power_w += float(c.get("safe_power_w", 0.0))
				s.downlink_rate_bps = maxf(s.downlink_rate_bps, float(c.get("rate_bps", 0.0)))
			"instrument":
				s.instrument_power_w += float(c.get("power_w", 0.0))
				s.instrument_rate_bps += float(c.get("data_rate_bps", 0.0))
			_:
				s.bus_power_w += float(c.get("power_w", 0.0))
				s.bus_safe_power_w += float(c.get("safe_power_w", 0.0))
				if c.get("category") == "battery":
					s.battery_capacity_j += float(c.get("capacity_j", 0.0))
					# packs are wired together, so the first one's thresholds rule
					if not battery_seen:
						battery_seen = true
						s.safe_enter_fraction = float(c.get("safe_enter_fraction", 0.0))
						s.safe_exit_fraction = float(c.get("safe_exit_fraction", 0.0))
				elif c.get("category") == "obc":
					s.storage_capacity_bits += float(c.get("storage_bits", 0.0))
				elif c.get("category") == "adcs":
					s.pointed = true
	if not s.pointed:
		s.instrument_rate_bps *= UNPOINTED_SHARE
	s.initial_energy_j = s.battery_capacity_j
	return s

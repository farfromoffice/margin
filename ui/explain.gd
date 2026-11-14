class_name Explain
extends RefCounted
## Turns sim output (violations, warnings, factors, raw numbers) into short
## sentences a first time player can follow.

const CATEGORY_NAMES := {
	"structure": "structure",
	"solar": "solar array",
	"battery": "battery",
	"comms": "radio",
	"obc": "onboard computer",
	"adcs": "pointing system",
	"instrument": "camera",
	"ground_station": "ground station",
	"launcher": "launcher",
}

## icon from ui/icons for each category and factor
const ICONS := {
	"structure": "cube",
	"solar": "solar",
	"battery": "battery",
	"comms": "antenna",
	"obc": "chip",
	"adcs": "gyro",
	"instrument": "camera",
	"ground_station": "dish",
	"launcher": "rocket",
	"orbit": "orbit",
	&"power": "bolt",
	&"storage": "chip",
	&"downlink": "dish",
}

const FACTOR_NAMES := {
	&"power": "Power",
	&"storage": "Storage",
	&"downlink": "Downlink",
}

const FACTOR_HINTS := {
	&"power": "The battery ran low and the spacecraft went into Safe mode, so the camera was off.",
	&"storage": "The memory filled up, so new pictures had to be thrown away.",
	&"downlink": "The radio could not send everything home in the time over the ground stations.",
}


## same factors, phrased as a guess before launch
const FACTOR_GUESSES := {
	&"power": "The battery runs low and Safe mode turns the camera off.",
	&"storage": "The memory fills up and new pictures get thrown away.",
	&"downlink": "The radio can't send everything home during the passes.",
}


static func category(cat: String) -> String:
	return CATEGORY_NAMES.get(cat, cat)


static func icon_for(key: Variant) -> String:
	return ICONS.get(key, "satellite")


static func violation(v: Dictionary) -> String:
	match v["kind"]:
		&"missing_part":
			return "Pick a %s." % category(str(v["value"]))
		&"unknown_component":
			return "Unknown part %s, remove it." % v["value"]
		&"orbit_not_allowed":
			return "This mission can't use that orbit."
		&"orbit_unreachable":
			return "The launcher can't reach this orbit."
		&"over_launcher_capacity":
			return "Too heavy for the launcher: %s of %s." % [kg(v["value"]), kg(v["limit"])]
		&"over_scenario_mass":
			return "Over the mission mass limit: %s of %s." % [kg(v["value"]), kg(v["limit"])]
		&"over_budget":
			return "Over budget: %s of %s." % [kusd(v["value"]), kusd(v["limit"])]
	return str(v["kind"])


static func warning(w: Dictionary) -> String:
	match w["kind"]:
		&"orbit_energy_negative":
			return "Power runs short: %s missing every orbit." % wh(-float(w["value"]))
		&"downlink_short":
			return "The camera makes %s a day, the radio can send %s." % [mb(w["value"]), mb(w["limit"])]
		&"storage_fills":
			return "Memory fills up after %s." % days(w["value"])
	return str(w["kind"])


static func factor(f: StringName) -> String:
	return FACTOR_NAMES.get(f, String(f))


static func factor_list(list: Array[StringName]) -> String:
	if list.is_empty():
		return "nothing"
	return ", ".join(list.map(func(f): return factor(f)))


static func goal(id: StringName, target: float) -> String:
	match id:
		&"delivered_mb":
			return "Send home %s of pictures" % mb(target * Outcome.BITS_PER_MB)
	return "%s: %s" % [id, target]


static func objective(row: Dictionary) -> String:
	var actual := "?"
	if row["actual"] != null:
		actual = mb(float(row["actual"]) * Outcome.BITS_PER_MB) if row["id"] == &"delivered_mb" else str(row["actual"])
	return "%s: %s" % [goal(row["id"], float(row["target"])), actual]


## "0.85 kg · 5.0 W · 7 kUSD", the line under every part button.
static func part_line(c: Dictionary) -> String:
	var bits: Array[String] = [kg(c.get("mass_kg", 0.0))]
	match str(c.get("category", "")):
		"solar":
			bits.append("%.1f W peak" % float(c.get("generated_w_1au", 0.0)))
		"battery":
			bits.append("%.0f Wh" % float(c.get("capacity_wh", 0.0)))
		"comms":
			bits.append(rate(c.get("rate_bps", 0.0)))
			bits.append("%.1f W sending" % float(c.get("power_w", 0.0)))
		"obc":
			bits.append("%.0f GB" % (float(c.get("storage_bytes", 0.0)) / 1.0e9))
			bits.append("%.1f W" % float(c.get("power_w", 0.0)))
		"instrument":
			bits.append(rate(c.get("data_rate_bps", 0.0)))
			bits.append("%.1f W" % float(c.get("power_w", 0.0)))
		_:
			if float(c.get("power_w", 0.0)) > 0.0:
				bits.append("%.1f W" % float(c.get("power_w", 0.0)))
	bits.append(kusd(c.get("cost_kusd", 0.0)))
	return " · ".join(bits)


static func kg(v: Variant) -> String:
	return "%.2f kg" % float(v)


static func kusd(v: Variant) -> String:
	return "%s kUSD" % _thousands(float(v))


static func wh(joules: float) -> String:
	return "%.1f Wh" % (joules / 3600.0)


## MB here is 10⁶ bytes, same as everywhere in the game.
static func mb(bits: Variant) -> String:
	var v := float(bits) / 8.0e6
	if v >= 1000.0:
		return "%s MB" % _thousands(v)
	return "%.1f MB" % v


static func rate(bps: Variant) -> String:
	var v := float(bps)
	if v >= 1.0e6:
		return "%.0f Mbit/s" % (v / 1.0e6)
	return "%.1f kbit/s" % (v / 1.0e3)


static func days(seconds: Variant) -> String:
	var d := float(seconds) / 86400.0
	return "%.1f days" % d if d >= 1.0 else "%.1f hours" % (d * 24.0)


## mission_time formats mission elapsed time like "Day 4, 06:10".
static func mission_time(t_s: float) -> String:
	var day := int(t_s / 86400.0) + 1
	var in_day := fmod(t_s, 86400.0)
	return "Day %d, %02d:%02d" % [day, int(in_day / 3600.0), int(fmod(in_day, 3600.0) / 60.0)]


const PAUSE_NAMES := {
	AutoPause.FAILURE: "Something broke",
	AutoPause.LOW_BATTERY: "Battery low",
	AutoPause.STORAGE_HIGH: "Memory 80 % full",
	AutoPause.CONTACT_BEGIN: "Pass begins, radio off",
	AutoPause.SAFE_ENTER: "Safe mode entered",
}

const PAUSE_REASONS := {
	AutoPause.FAILURE: "",
	AutoPause.LOW_BATTERY: "The battery is getting low. Safe mode will switch the camera off soon unless the camera or the radio uses less.",
	AutoPause.STORAGE_HIGH: "The memory is 80 % full. When it is full, new pictures are thrown away.",
	AutoPause.CONTACT_BEGIN: "A ground station is in view and the radio is off. Switch it on to send pictures home during this pass.",
	AutoPause.SAFE_ENTER: "The battery ran low and the spacecraft went into Safe mode.",
}


static func pause_reasons(fired: Array[StringName]) -> String:
	return " ".join(fired.map(func(k): return PAUSE_REASONS.get(k, String(k)))).strip_edges()


## Short name of a failure kind from failures.json, or the raw id if it is gone.
static func failure_name(kind: StringName) -> String:
	return str(Catalog.get_entry("failures", kind).get("name", kind))


## What broke and what the player can do about it, for the pause banner.
static func failure_alert(kind: StringName) -> String:
	var e := Catalog.get_entry("failures", kind)
	return "%s. %s %s" % [failure_name(kind), e.get("explain", ""), e.get("fix", "")]


## Report lines for every failure of a run: when it struck, what it did, and
## for hangs how long they lasted.
static func failure_lines(r: RunResult) -> Array[String]:
	var out: Array[String] = []
	for e in r.events:
		if e["kind"] != &"failure":
			continue
		var kind: StringName = e["failure"]
		var line := "%s: %s." % [mission_time(float(e["t_s"])), failure_name(kind)]
		match kind:
			&"battery_fade":
				line += " The battery lost %d %% of what it could hold." % roundi(float(e["magnitude"]) * 100.0)
			&"solar_loss":
				line += " The solar array lost %d %% of its output." % roundi(float(e["magnitude"]) * 100.0)
			_:
				var fixed := _recovery_t(r, kind, float(e["t_s"]))
				if fixed < 0.0:
					line += " Never fixed, %s without it." % days(r.end_t_s - float(e["t_s"]))
				else:
					line += " Fixed after %s." % days(fixed - float(e["t_s"]))
		out.append(line)
	return out


static func _recovery_t(r: RunResult, kind: StringName, after_s: float) -> float:
	for e in r.events:
		if e["kind"] == &"recovered" and e["failure"] == kind and float(e["t_s"]) >= after_s:
			return float(e["t_s"])
	return -1.0


## duty describes a camera duty cycle. Zero reads as off, since "on 0 % of the
## time" made players look elsewhere for an off switch.
static func duty(v: float) -> String:
	if roundi(v * 100.0) <= 0:
		return "Camera off"
	return "Camera on %d %% of the time" % roundi(v * 100.0)


static func command(c: Dictionary) -> String:
	var what := ""
	match c["control"]:
		Controls.DUTY_CYCLE:
			what = duty(float(c["value"])).to_lower()
		Controls.RADIO_ENABLED:
			what = "radio on" if c["value"] else "radio off"
		_:
			what = "%s = %s" % [c["control"], c["value"]]
	return "%s: %s" % [mission_time(float(c["t_s"])), what]


## forecast turns the numbers of Warnings.forecast into lines for the operations
## screen. The numbers are averages and the times read as "about".
static func forecast(f: Dictionary, s: SimState) -> Array[String]:
	var lines: Array[String] = []
	var net := float(f["energy_per_orbit_j"])
	lines.append("Power per orbit: %s%s" % ["+" if net >= 0.0 else "", wh(net)])
	lines.append("Data per day: %s made, %s can be sent" % [mb(f["generated_bits_per_day"]), mb(f["sendable_bits_per_day"])])
	var remaining := float(f["remaining_s"])
	var full := float(f["storage_full_in_s"])
	if s.stored_bits > 0.0 and full == 0.0:
		lines.append("Memory: full now")
	elif full < remaining:
		lines.append("Memory full in about %s" % days(full))
	else:
		lines.append("Memory: does not fill before the end")
	var safe := float(f["safe_mode_in_s"])
	if s.mode == RunResult.Mode.SAFE:
		lines.append("Safe mode: in it now")
	elif safe < remaining:
		lines.append("Safe mode in about %s" % days(safe))
	else:
		lines.append("Safe mode: not expected")
	return lines


static func _thousands(v: float) -> String:
	var sign := "-" if v < 0.0 else ""
	var s := str(absi(int(round(v))))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return sign + s + out

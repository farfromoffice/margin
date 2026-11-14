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


static func _thousands(v: float) -> String:
	var sign := "-" if v < 0.0 else ""
	var s := str(absi(int(round(v))))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return sign + s + out

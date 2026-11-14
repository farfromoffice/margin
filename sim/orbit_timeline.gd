class_name OrbitTimeline
extends RefCounted
## Eclipse and contact intervals for one run, built from an orbits.json entry.
## Walk it forward with advance(); it answers how many seconds of each step were
## sunlit and in contact, so short passes don't get rounded to whole steps.

const MU_M3_S2 := 3.986004418e14
const R_EARTH_M := 6378137.0

var period_s := 0.0
var eclipse_fraction := 0.0
var duration_s := 0.0
## flat [start, end, start, end, ...], sorted, non overlapping. float64 on purpose,
## float32 drifts by about 0.25 s at 30 days.
var eclipses := PackedFloat64Array()
var contacts := PackedFloat64Array()

## results of the last advance() call
var sunlit_s := 0.0
var contact_s := 0.0
## contact intervals that began inside the step
var contact_starts := 0

var _eclipse_cursor := 0
var _contact_cursor := 0


## T = 2π√(a³/μ) for a circular orbit at this altitude.
static func period_for_altitude_s(altitude_m: float) -> float:
	var a := R_EARTH_M + altitude_m
	return TAU * sqrt(a * a * a / MU_M3_S2)


## orbit is a Catalog entry (SI fields already added). Stations without contact
## data for this orbit simply add nothing.
static func build(orbit: Dictionary, station_ids: Array[StringName], p_duration_s: float) -> OrbitTimeline:
	var t := OrbitTimeline.new()
	t.duration_s = p_duration_s
	t.period_s = period_for_altitude_s(float(orbit.get("altitude_m", 0.0)))
	t.eclipse_fraction = clampf(float(orbit.get("eclipse_fraction", 0.0)), 0.0, 1.0)
	t.eclipses = _build_eclipses(t.period_s, t.eclipse_fraction, p_duration_s)
	t.contacts = _build_contacts(orbit, station_ids, p_duration_s)
	return t


## Same intervals, cursors back at the start. A second run can walk them.
func rewound() -> OrbitTimeline:
	var t := OrbitTimeline.new()
	t.period_s = period_s
	t.eclipse_fraction = eclipse_fraction
	t.duration_s = duration_s
	t.eclipses = eclipses
	t.contacts = contacts
	return t


## Fills sunlit_s and contact_s for [t_s, t_s + dt_s). Calls must move forward
## in time, the cursors never go back.
func advance(t_s: float, dt_s: float) -> void:
	var dark := _overlap(eclipses, t_s, t_s + dt_s, true)
	sunlit_s = dt_s - dark
	contact_s = _overlap(contacts, t_s, t_s + dt_s, false)


func total_contact_s() -> float:
	return _sum(contacts)


## Average contact seconds per day over the whole run, used by the warnings.
func contact_s_per_day() -> float:
	return total_contact_s() / duration_s * 86400.0 if duration_s > 0.0 else 0.0


func _overlap(list: PackedFloat64Array, from_s: float, to_s: float, is_eclipse: bool) -> float:
	var i := _eclipse_cursor if is_eclipse else _contact_cursor
	var n := list.size()
	while i < n and list[i + 1] <= from_s:
		i += 2
	if is_eclipse:
		_eclipse_cursor = i
	else:
		_contact_cursor = i
	var total := 0.0
	var starts := 0
	while i < n and list[i] < to_s:
		total += minf(list[i + 1], to_s) - maxf(list[i], from_s)
		if list[i] >= from_s:
			starts += 1
		i += 2
	if not is_eclipse:
		contact_starts = starts
	return total


static func _build_eclipses(period: float, fraction: float, duration: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	if period <= 0.0 or fraction <= 0.0:
		return out
	var k := 0
	while k * period < duration:
		var start := k * period + (1.0 - fraction) * period
		if start < duration:
			out.append(start)
			out.append(minf((k + 1) * period, duration))
		k += 1
	return out


static func _build_contacts(orbit: Dictionary, station_ids: Array[StringName], duration: float) -> PackedFloat64Array:
	var reference := float(orbit.get("reference_duration_s", 0.0))
	var by_station: Variant = orbit.get("contacts_s", {})
	if reference <= 0.0 or not by_station is Dictionary:
		return PackedFloat64Array()
	var starts: Array[float] = []
	var ends: Array[float] = []
	for id in station_ids:
		var windows: Variant = by_station.get(String(id))
		if not windows is Array:
			continue
		var offset := 0.0
		while offset < duration:
			for w in windows:
				if not (w is Array and w.size() == 2):
					continue
				var s := float(w[0]) + offset
				if s >= duration:
					continue
				starts.append(s)
				ends.append(minf(float(w[1]) + offset, duration))
			offset += reference
	# hmm, sort indices instead of pairs so the floats never pass through Vector2
	var order := range(starts.size())
	order.sort_custom(func(a, b): return starts[a] < starts[b])
	var out := PackedFloat64Array()
	for i in order:
		var n := out.size()
		# one radio, so two stations seeing us at once still counts once
		if n > 0 and starts[i] <= out[n - 1]:
			out[n - 1] = maxf(out[n - 1], ends[i])
		else:
			out.append(starts[i])
			out.append(ends[i])
	return out


static func _sum(list: PackedFloat64Array) -> float:
	var total := 0.0
	for i in range(0, list.size(), 2):
		total += list[i + 1] - list[i]
	return total

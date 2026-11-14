extends Control
## After the run: did we meet the goal, where did the data go, what held the
## mission back and how that compares with the prediction. Redesign goes back
## to the design screen with everything still picked.


func _ready() -> void:
	var r := GameState.last_result
	var s := GameState.scenario()
	var page := UiStyle.page(self, 28)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var col := UiStyle.vbox(14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	col.add_child(UiStyle.section("MISSION REPORT", "satellite", 14, UiStyle.CYAN))
	if r.end_reason == RunResult.EndReason.POWER_LOST:
		col.add_child(_title("Mission lost on day %d" % (int(r.end_t_s / 86400.0) + 1), UiStyle.BAD))
	else:
		col.add_child(_title("Mission complete", UiStyle.GOOD))

	var grid := UiStyle.hbox(16)
	col.add_child(grid)
	grid.add_child(_card("Goal", _goal_lines(s, r), "flag"))
	grid.add_child(_card("Where the data went", _data_lines(r), "data"))
	grid.add_child(_card("Power", _power_lines(r), "bolt"))

	var actual := Outcome.limiting_factors(r)
	col.add_child(_card("Your prediction", _prediction_lines(actual), "star"))
	if not actual.is_empty():
		var why: Array = []
		for f in actual:
			why.append(["%s: %s" % [Explain.factor(f), Explain.FACTOR_HINTS[f]], UiStyle.TEXT])
		col.add_child(_card("What happened", why, "satellite"))
	var failures := Explain.failure_lines(r)
	if not failures.is_empty():
		var lines: Array = failures.map(func(l): return [l, UiStyle.WARN])
		lines.append(["The comparison below flies the same failures with nobody at the controls.", UiStyle.MUTED])
		col.add_child(_card("Failures in flight", lines, "chip"))
	if GameState.baseline_result:
		col.add_child(_card("Design vs. operations", _operations_lines(r, GameState.baseline_result, s), "camera"))
	if not GameState.last_warnings.is_empty():
		var notes: Array = GameState.last_warnings.map(func(w): return [Explain.warning(w), UiStyle.WARN])
		col.add_child(_card("The design screen warned about", notes, "flag"))

	var buttons := UiStyle.hbox(12)
	buttons.add_child(UiStyle.button("Main menu", func(): EventBus.screen_requested.emit(&"main_menu")))
	var again := UiStyle.button("Redesign and fly again", func(): EventBus.screen_requested.emit(&"design"))
	again.icon = UiStyle.icon("rocket")
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(again)
	col.add_child(buttons)


func _title(text: String, color: Color) -> Label:
	var l := UiStyle.label(text, 34, color)
	l.theme_type_variation = &"DisplayLabel"
	return l


## lines are [text, color] pairs
func _card(title: String, lines: Array, icon_name: String) -> PanelContainer:
	var box := UiStyle.vbox(6)
	box.add_child(UiStyle.section(title, icon_name))
	for line in lines:
		box.add_child(UiStyle.label(line[0], 16, line[1], true))
	var p := UiStyle.panel(box)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func _goal_lines(s: Scenario, r: RunResult) -> Array:
	var out: Array = []
	for row in Outcome.objectives(s, r):
		out.append([("Met. " if row["met"] else "Not met. ") + Explain.objective(row), UiStyle.GOOD if row["met"] else UiStyle.BAD])
	if out.is_empty():
		out.append(["No goal in this mission. %s sent home." % Explain.mb(r.delivered_bits_total), UiStyle.TEXT])
	var prev := GameState.previous_result
	if prev:
		var diff := r.delivered_bits_total - prev.delivered_bits_total
		out.append(["Last flight sent %s, this one %s%s." % [Explain.mb(prev.delivered_bits_total), "+" if diff >= 0.0 else "-", Explain.mb(absf(diff))], UiStyle.MUTED])
	return out


func _data_lines(r: RunResult) -> Array:
	var out: Array = [
		["Taken: %s" % Explain.mb(r.generated_bits_total), UiStyle.TEXT],
		["Sent home: %s" % Explain.mb(r.delivered_bits_total), UiStyle.GOOD],
	]
	if r.discarded_bits_total > 0.0:
		out.append(["Thrown away, memory full: %s" % Explain.mb(r.discarded_bits_total), UiStyle.BAD])
	if r.stored_bits_end > 0.0:
		out.append(["Still on board at the end: %s" % Explain.mb(r.stored_bits_end), UiStyle.WARN])
	if r.missed_bits_total > 0.0:
		out.append(["Never taken, camera off in Safe mode: %s" % Explain.mb(r.missed_bits_total), UiStyle.BAD])
	return out


func _power_lines(r: RunResult) -> Array:
	var cap := GameState.last_input.battery_capacity_j
	var lowest: float = Array(r.energy_j).min() if r.step_count() > 0 else 0.0
	var out: Array = [["Lowest battery: %d %%" % roundi(100.0 * lowest / maxf(cap, 1.0)), UiStyle.TEXT]]
	if r.safe_entries > 0:
		out.append(["Safe mode %d times, %s in total" % [r.safe_entries, Explain.days(r.safe_time_s)], UiStyle.BAD])
	else:
		out.append(["Never needed Safe mode", UiStyle.GOOD])
	return out


func _operations_lines(r: RunResult, base: RunResult, s: Scenario) -> Array:
	var cmp := Outcome.compare_runs(r, base, s)
	if not cmp["intervened"]:
		return [["You changed nothing in flight, so this is the design's own result.", UiStyle.TEXT]]
	const SHOWN := 6
	var out: Array = [["Your changes in flight:", UiStyle.TEXT]]
	for c in r.commands.slice(0, SHOWN):
		out.append(["  " + Explain.command(c), UiStyle.CYAN])
	if r.commands.size() > SHOWN:
		out.append(["  and %d more" % (r.commands.size() - SHOWN), UiStyle.MUTED])

	out.append(["Compared with the same design left alone:", UiStyle.TEXT])
	var sent: Dictionary = cmp["delivered_bits"]
	match sent["verdict"]:
		&"more":
			out.append(["Your operations sent home %s more (%s instead of %s)." % [Explain.mb(sent["diff"]), Explain.mb(sent["operated"]), Explain.mb(sent["baseline"])], UiStyle.GOOD])
		&"less":
			out.append(["Your changes cost %s of data sent home (%s instead of %s)." % [Explain.mb(-float(sent["diff"])), Explain.mb(sent["operated"]), Explain.mb(sent["baseline"])], UiStyle.BAD])
		_:
			out.append(["Data sent home: no real difference (%s)." % Explain.mb(sent["operated"]), UiStyle.MUTED])
	var lost: Dictionary = cmp["discarded_bits"]
	if lost["verdict"] != &"same":
		out.append(["Thrown away: %s instead of %s." % [Explain.mb(lost["operated"]), Explain.mb(lost["baseline"])], UiStyle.GOOD if lost["verdict"] == &"less" else UiStyle.BAD])
	var safe: Dictionary = cmp["safe_time_s"]
	if safe["verdict"] != &"same":
		out.append(["Time in Safe mode: %s instead of %s." % [Explain.days(safe["operated"]), Explain.days(safe["baseline"])], UiStyle.GOOD if safe["verdict"] == &"less" else UiStyle.BAD])
	var done: Dictionary = cmp["completed"]
	if done["operated"] != done["baseline"]:
		var text := "Your operations kept the spacecraft alive; left alone it would have been lost." if done["operated"] \
				else "The spacecraft was lost; left alone it would have finished the mission."
		out.append([text, UiStyle.GOOD if done["operated"] else UiStyle.BAD])
	var met: Dictionary = cmp["objectives_met"]
	if met["operated"] != met["baseline"]:
		var text := "The goal was met thanks to your operations; the design alone would have missed it." if met["operated"] \
				else "The design alone would have met the goal; your changes made it miss."
		out.append([text, UiStyle.GOOD if met["operated"] else UiStyle.BAD])
	return out


func _prediction_lines(actual: Array[StringName]) -> Array:
	var predicted := GameState.prediction
	var c := Outcome.compare_prediction(predicted, actual)
	var out: Array = [
		["You expected: %s" % Explain.factor_list(predicted), UiStyle.TEXT],
		["What limited it: %s" % Explain.factor_list(actual), UiStyle.TEXT],
	]
	if c["missed"].is_empty() and c["wrong"].is_empty():
		out.append(["Spot on.", UiStyle.GOOD])
	else:
		if not c["hit"].is_empty():
			out.append(["Right about: %s" % Explain.factor_list(c["hit"]), UiStyle.GOOD])
		if not c["missed"].is_empty():
			out.append(["Did not see coming: %s" % Explain.factor_list(c["missed"]), UiStyle.BAD])
		if not c["wrong"].is_empty():
			out.append(["Turned out fine: %s" % Explain.factor_list(c["wrong"]), UiStyle.WARN])
	return out

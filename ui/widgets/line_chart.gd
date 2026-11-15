class_name LineChart
extends Control
## One time series drawn left to right over the whole mission. progress (0..1)
## reveals it gradually for the playback. Safe mode steps get a red tint.

var title := ""
var color := UiStyle.DATA
## series values, one per sim step
var values := PackedFloat64Array()
## RunResult.mode per step, optional
var modes := PackedByteArray()
## steps the full mission would have; a lost mission has fewer values than this
var total_steps := 1
var max_value := 1.0
var progress := 1.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		queue_redraw()
## turns the value under the playhead into the label text
var format := func(v: float) -> String: return "%.1f" % v
## Value where a dashed reference line is drawn, in the same unit as values. A
## negative value draws no line.
var threshold := -1.0
var threshold_label := ""
## red for a limit to stay away from, another color for a target to reach
var threshold_color := UiStyle.BAD

const PAD := Vector2(10, 28)


func _init() -> void:
	custom_minimum_size = Vector2(300, 130)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.PANEL)
	var plot := Rect2(PAD, size - PAD * Vector2(2, 1.4))
	draw_line(Vector2(plot.position.x, plot.end.y), plot.end, UiStyle.PANEL_LIGHT, 1.0)
	draw_line(plot.position, Vector2(plot.end.x, plot.position.y), UiStyle.PANEL_LIGHT, 1.0)
	draw_string(font, Vector2(PAD.x, 19), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiStyle.MUTED)
	_draw_series(plot, font)
	# The threshold is drawn last. The Safe mode bands and the series would cover it.
	if threshold >= 0.0:
		var ty := _y(plot, threshold)
		var line_color := Color(threshold_color, 0.9)
		# width -1 draws a hairline, always one screen pixel.
		# and a 1.0 wide line shrinks below a pixel in a window smaller than 1280x720,
		#  vanishes at some heights. So a goal line that moves with the data blinks in and out.
		draw_dashed_line(Vector2(plot.position.x, ty), Vector2(plot.end.x, ty), line_color, -1.0, 6.0)
		var text_size := font.get_string_size(threshold_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var at := Vector2(plot.end.x - text_size.x - 4, ty - 4)
		draw_rect(Rect2(at - Vector2(3, text_size.y - 2), text_size + Vector2(6, 2)), UiStyle.PANEL)
		draw_string(font, at, threshold_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, line_color)


func _draw_series(plot: Rect2, font: Font) -> void:
	var shown := mini(int(progress * total_steps), values.size())
	if shown < 1 or plot.size.x < 2.0:
		return
	# a 30 day run has far more steps than pixels, so each column draws the
	# min..max of its steps as a band and the line follows the column mean.
	# Picking one step per column instead turns orbit by orbit swings into noise.
	var columns := int(plot.size.x)
	var per_col := float(total_steps) / columns
	var points := PackedVector2Array()
	var band := Color(color, 0.35)
	for col in columns:
		var first := int(col * per_col)
		if first >= shown:
			break
		var last := mini(int((col + 1) * per_col), shown)
		var lo := INF
		var hi := -INF
		var sum := 0.0
		var safe := false
		for i in range(first, maxi(last, first + 1)):
			var v: float = values[i]
			lo = minf(lo, v)
			hi = maxf(hi, v)
			sum += v
			safe = safe or (i < modes.size() and modes[i] == RunResult.Mode.SAFE)
		var x := plot.position.x + col
		if safe:
			draw_rect(Rect2(x, plot.position.y, 1.0, plot.size.y), Color(UiStyle.BAD, 0.25))
		draw_line(Vector2(x, _y(plot, lo)), Vector2(x, _y(plot, hi)), band, 1.0)
		points.append(Vector2(x, _y(plot, sum / maxi(last - first, 1))))
	if points.size() >= 2:
		draw_polyline(points, color, 2.0, true)
	var now: float = values[shown - 1]
	var text: String = format.call(now)
	draw_string(font, Vector2(size.x - PAD.x - 160, 19), text, HORIZONTAL_ALIGNMENT_RIGHT, 160, 15, color)
	if not points.is_empty():
		draw_circle(points[points.size() - 1], 3.0, color)


func _y(plot: Rect2, v: float) -> float:
	return plot.end.y - clampf(v / max_value, 0.0, 1.0) * plot.size.y

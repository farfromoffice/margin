class_name MarginMeter
extends VBoxContainer
## Title, "value / limit" text and a bar that turns yellow near the limit and
## red past it. A limit of 0 means there is none, the bar stays empty.

const NEAR_LIMIT := 0.85

var _title: Label
var _value: Label
var _bar: Control
var _ratio := 0.0


func _init(title: String, icon_name: String) -> void:
	add_theme_constant_override("separation", 4)
	var row := UiStyle.hbox(8)
	row.add_child(UiStyle.icon_rect(icon_name, 18, UiStyle.MUTED))
	_title = UiStyle.label(title, 15, UiStyle.MUTED)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_value = UiStyle.label("", 15)
	row.add_child(_title)
	row.add_child(_value)
	add_child(row)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0, 10)
	_bar.draw.connect(_draw_bar)
	add_child(_bar)


func set_values(value_text: String, limit_text: String, value: float, limit: float) -> void:
	_value.text = value_text if limit <= 0.0 else "%s / %s" % [value_text, limit_text]
	_ratio = value / limit if limit > 0.0 else 0.0
	_value.add_theme_color_override("font_color", color_for(_ratio))
	_bar.queue_redraw()


static func color_for(ratio: float) -> Color:
	if ratio > 1.0:
		return UiStyle.BAD
	if ratio > NEAR_LIMIT:
		return UiStyle.WARN
	return UiStyle.GOOD


func _draw_bar() -> void:
	var r := Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_rect(r, UiStyle.PANEL_LIGHT)
	var fill := r
	fill.size.x *= clampf(_ratio, 0.0, 1.0)
	_bar.draw_rect(fill, color_for(_ratio))

class_name UiStyle
extends RefCounted
## Colors, the shared Theme and a few node factories so every screen looks the
## same without a pile of .tres files.

const BG := Color("060914")
## panels are see through so the starfield keeps moving behind them
const PANEL := Color(0.08, 0.11, 0.2, 0.82)
const PANEL_LIGHT := Color(0.14, 0.19, 0.32, 0.9)
const LINE := Color(0.39, 0.82, 1.0, 0.22)
const CYAN := Color("63d2ff")
const TEXT := Color("e6e9f2")
const MUTED := Color("8b93ad")
const ACCENT := Color("f2a93b")
const GOOD := Color("5cc98a")
const WARN := Color("f2c94c")
const BAD := Color("e8575a")
const DATA := Color("5aa9e6")

## Orbitron for titles, tabs and action buttons, Exo 2 for everything you read.
## Both are variable fonts, the weight is picked per use below.
const DISPLAY_FONT := preload("res://ui/fonts/Orbitron.ttf")
const BODY_FONT := preload("res://ui/fonts/Exo2.ttf")


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = _weight(BODY_FONT, 500)
	t.default_font_size = 17
	var display := _weight(DISPLAY_FONT, 700)
	t.set_type_variation(&"DisplayLabel", &"Label")
	t.set_font("font", &"DisplayLabel", display)
	t.set_type_variation(&"DisplayButton", &"Button")
	t.set_font("font", &"DisplayButton", _weight(DISPLAY_FONT, 600))
	t.set_font_size("font_size", &"DisplayButton", 15)
	t.set_font("font", "TabContainer", _weight(DISPLAY_FONT, 600))
	t.set_font_size("font_size", "TabContainer", 13)
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 10, 16, LINE, 1))
	t.set_stylebox("normal", "Button", _box(PANEL_LIGHT, 6, 10, LINE, 1))
	t.set_stylebox("hover", "Button", _box(PANEL_LIGHT.lightened(0.12), 6, 10, Color(CYAN, 0.6), 1))
	t.set_stylebox("pressed", "Button", _box(ACCENT.darkened(0.45), 6, 10, ACCENT))
	t.set_stylebox("hover_pressed", "Button", _box(ACCENT.darkened(0.35), 6, 10, ACCENT))
	t.set_stylebox("disabled", "Button", _box(PANEL_LIGHT.darkened(0.3), 6, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_hover_pressed_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_stylebox("panel", "TabContainer", _box(PANEL, 10, 16, LINE, 1))
	t.set_constant("icon_separation", "Button", 10)
	t.set_constant("icon_max_width", "Button", 26)
	t.set_constant("icon_max_width", "TabContainer", 16)
	t.set_stylebox("tab_selected", "TabContainer", _box(PANEL, 6, 8))
	t.set_stylebox("tab_unselected", "TabContainer", _box(Color(BG, 0.6), 6, 8))
	t.set_stylebox("tab_hovered", "TabContainer", _box(PANEL_LIGHT, 6, 8))
	t.set_color("font_selected_color", "TabContainer", ACCENT)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	return t


static func label(text: String, size := 17, color := TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func heading(text: String, size := 30) -> Label:
	var l := label(text, size, ACCENT)
	l.theme_type_variation = &"DisplayLabel"
	return l


## Action buttons (next, back, launch) get the display font; part pickers don't.
static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"DisplayButton"
	b.text = text
	b.pressed.connect(on_pressed)
	return b


static func panel(content: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_child(content)
	return p


static func vbox(separation := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


## Full screen root with the usual page padding; add the page content to it.
static func page(root: Control, margin := 28) -> MarginContainer:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, margin)
	root.add_child(m)
	return m


## White line icon from ui/icons, tint it with modulate or self_modulate.
static func icon(icon_name: String) -> Texture2D:
	return load("res://ui/icons/%s.svg" % icon_name)


static func icon_rect(icon_name: String, px := 22, tint := CYAN) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(icon_name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.modulate = tint
	return r


## Section title with its icon in front, the way every block starts.
static func section(text: String, icon_name: String, size := 18, color := ACCENT) -> HBoxContainer:
	var row := hbox(8)
	row.add_child(icon_rect(icon_name, size + 4, color))
	var l := label(text, size, color)
	l.theme_type_variation = &"DisplayLabel"
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


static func _weight(font: FontFile, weight: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = font
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return v


static func _box(color: Color, radius: int, pad: int, border := Color.TRANSPARENT, width := 2) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(pad)
	if border.a > 0.0:
		b.border_color = border
		b.set_border_width_all(width)
	return b

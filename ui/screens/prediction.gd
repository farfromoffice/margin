extends Control
## Before launch the players commit to what they think will hold the design
## back. The report holds them to it.

var _boxes := {}
var _none: CheckBox


func _ready() -> void:
	var page := UiStyle.page(self, 60)
	var col := UiStyle.vbox(16)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.custom_minimum_size.x = 720
	page.add_child(col)
	col.add_child(UiStyle.section("PREDICTION", "star", 14, UiStyle.CYAN))
	col.add_child(UiStyle.heading("What will limit your design?", 34))
	col.add_child(UiStyle.label("Pick everything you expect to hold this design back if nothing breaks and nobody touches the controls. The report checks your guess against exactly that run; failures and your changes in flight are judged apart.", 18, UiStyle.TEXT, true))

	var picks := UiStyle.vbox(10)
	for f in Outcome.FACTORS:
		var cb := CheckBox.new()
		cb.text = "%s  ·  %s" % [Explain.factor(f), Explain.FACTOR_GUESSES[f]]
		cb.icon = UiStyle.icon(Explain.icon_for(f))
		cb.add_theme_color_override("icon_normal_color", UiStyle.CYAN)
		cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.button_pressed = f in GameState.prediction
		cb.toggled.connect(func(on: bool): if on: _none.button_pressed = false)
		_boxes[f] = cb
		picks.add_child(cb)
	_none = CheckBox.new()
	_none.text = "Nothing, it will run fine"
	_none.toggled.connect(func(on: bool):
		if on:
			for cb in _boxes.values():
				cb.button_pressed = false)
	picks.add_child(_none)
	col.add_child(UiStyle.panel(picks))

	var buttons := UiStyle.hbox(12)
	buttons.add_child(UiStyle.button("Back to design", func(): EventBus.screen_requested.emit(&"design")))
	var go := UiStyle.button("To the launch pad", _launch)
	go.icon = UiStyle.icon("rocket")
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(go)
	col.add_child(buttons)


## Escape goes back to the design.
func on_escape() -> void:
	EventBus.screen_requested.emit(&"design")


func _launch() -> void:
	GameState.prediction.clear()
	for f in _boxes:
		if _boxes[f].button_pressed:
			GameState.prediction.append(f)
	EventBus.screen_requested.emit(&"launch")

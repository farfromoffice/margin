extends Control
## How to play: the mission phases in order, then the few ideas the game keeps
## coming back to. Reachable from the main menu, no game state needed.

const PHASES := [
	["flag", "1. Briefing", "Read what the mission is for, how long it flies and the limits on money, mass and orbit."],
	["cube", "2. Design", "Pick the parts, the orbit, the launcher and the ground stations. The panel on the right shows mass, cost, power per orbit and data per day as you go. Launch stays locked until the design fits."],
	["star", "3. Prediction", "Guess what will hold your design back: power, storage or downlink, if nothing breaks and nobody touches the controls. The report checks your guess against that run."],
	["rocket", "4. Launch pad", "Last look at the numbers, then watch the launch. The launcher flies itself; your choice of launcher was the decision."],
	["satellite", "5. Operations", "The mission runs live. Change the camera time and the radio, react to pauses and failures."],
	["data", "6. Report", "Where the data went, what limited it, and how your flying compared with leaving the spacecraft alone. Then redesign and fly again."],
]

const IDEAS := [
	["bolt", "Power", "Solar panels charge the battery only in sunlight. In Earth's shadow everything runs on the battery. When the charge drops below the battery's Safe line the spacecraft enters Safe mode: camera off, radio only listening, until it recharges."],
	["camera", "Pointing", "A pointing system turns the spacecraft so the camera faces the ground. Without one it faces the ground only about a quarter of the time, so only that share of the pictures count."],
	["chip", "Data", "The camera fills the memory, the radio empties it, but only while a ground station is in view. A full memory throws new pictures away."],
	["orbit", "Time", "Pause, 1×, 4× or 16×. The game pauses on its own when a decision is due: battery low, memory filling, a pass with the radio off, or a failure."],
	["gyro", "Failures", "Parts break in flight. A frozen radio or camera comes back with a restart (the Restart buttons under Spacecraft health light up when one is needed). A weaker battery or solar array stays weak: use less power for the rest of the mission. On the launch pad you pick how many may strike: Training (1 to 3), Uncertain (0 to 3) or None."],
	["weight", "Margin", "Every gram, watt and megabyte you keep spare is margin. Margin is what lets the mission survive the eclipse, the slow pass and the failure you did not plan for."],
	["star", "Where numbers come from", "Every part carries a source and a label: documented, approximation or fictional. Orbits and passes come from NASA GMAT runs. Failure timing is a teaching value."],
	["planet", "What the model leaves out", "Power and data are simple averages each minute. The pictures are counted as megabytes: the game makes no real images and finds no real fires. No air drag, heat or radio link budget. Costs and failure rates are made up."],
	["coin", "Words on the screens", "kUSD: thousand US dollars. W in full sun: what a panel makes facing the Sun, the average over an orbit is lower. Wh: energy, one watt for one hour. MB: megabytes of pictures. Safe mode: camera off, radio only listening, until the battery recovers."],
]


func _ready() -> void:
	var page := UiStyle.page(self, 40)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var col := UiStyle.vbox(14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	col.add_child(UiStyle.section("HOW TO PLAY", "star", 14, UiStyle.CYAN))
	col.add_child(UiStyle.heading("Design it, fly it, find out why", 34))
	col.add_child(UiStyle.label("You run a small satellite mission from the first sketch to the last picture sent home. Nobody steers a rocket here: you make engineering decisions and live with them.", 18, UiStyle.TEXT, true))

	col.add_child(UiStyle.section("A mission, step by step", "flag", 20))
	col.add_child(_grid(PHASES, 3))
	col.add_child(UiStyle.section("What to keep an eye on", "satellite", 20))
	col.add_child(_grid(IDEAS, 3))
	col.add_child(UiStyle.label("Mouse: drag the 3D spacecraft or the Earth to turn them, wheel to zoom.", 15, UiStyle.MUTED, true))

	var back := UiStyle.button("Back to the menu", func(): EventBus.screen_requested.emit(&"main_menu"))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(back)


## Escape goes back to the menu like the button.
func on_escape() -> void:
	EventBus.screen_requested.emit(&"main_menu")


func _grid(cards: Array, columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for c in cards:
		var box := UiStyle.vbox(6)
		box.add_child(UiStyle.section(c[1], c[0], 17))
		box.add_child(UiStyle.label(c[2], 15, UiStyle.TEXT, true))
		var p := UiStyle.panel(box)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.size_flags_vertical = Control.SIZE_FILL
		grid.add_child(p)
	return grid

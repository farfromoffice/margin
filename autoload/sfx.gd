extends Node

const SOUNDS := {
	&"hover": preload("res://ui/sounds/tick_002.ogg"),
	&"click": preload("res://ui/sounds/select_002.ogg"),
	&"toggle_on": preload("res://ui/sounds/toggle_002.ogg"),
	&"toggle_off": preload("res://ui/sounds/toggle_001.ogg"),
	&"slider": preload("res://ui/sounds/tick_001.ogg"),
	&"liftoff": preload("res://ui/sounds/confirmation_002.ogg"),
	&"pause": preload("res://ui/sounds/question_002.ogg"),
	&"failure": preload("res://ui/sounds/error_004.ogg"),
	&"safe_mode": preload("res://ui/sounds/error_006.ogg"),
	&"goal_met": preload("res://ui/sounds/confirmation_001.ogg"),
	&"goal_missed": preload("res://ui/sounds/minimize_006.ogg"),
}

const VOLUME_DB := {
	&"hover": -24.0,
	&"click": -10.0,
	&"toggle_on": -12.0,
	&"toggle_off": -12.0,
	&"slider": -14.0,
	&"liftoff": -6.0,
	&"pause": -8.0,
	&"failure": -4.0,
	&"safe_mode": -6.0,
	&"goal_met": -6.0,
	&"goal_missed": -6.0,
}
## enough for a click to overlap a pause and a failure on the same frame
const VOICES := 6

var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	get_tree().node_added.connect(_on_node_added)


## play starts a sound on the next voice, cutting off the oldest one when all are
## busy. Clicks vary their pitch a little so fast clicking does not sound like a
## machine gun.
func play(sound: StringName) -> void:
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = SOUNDS[sound]
	p.volume_db = VOLUME_DB[sound]
	p.pitch_scale = randf_range(0.94, 1.06) if sound in [&"hover", &"click", &"slider"] else 1.0
	p.play()


## _on_node_added wires the sounds of a control as it enters the tree. CheckBox
## and CheckButton use toggled, which tells on from off; they also emit pressed,
## so they skip the click. set_pressed_no_signal stays silent, which keeps the
## screens' own syncing out of the sound.
func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		var b: BaseButton = n
		b.mouse_entered.connect(func():
			if not b.disabled:
				play(&"hover"))
		if b is CheckBox or b is CheckButton:
			b.toggled.connect(func(on: bool): play(&"toggle_on" if on else &"toggle_off"))
		else:
			b.pressed.connect(play.bind(&"click"))
	elif n is Slider:
		(n as Slider).drag_ended.connect(func(_changed: bool): play(&"slider"))

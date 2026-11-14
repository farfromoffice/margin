class_name Controls
extends RefCounted
## Controls holds the choices the player can still change after launch. Everything
## else is in SimInput and stays fixed during the mission.

const DUTY_CYCLE := &"duty_cycle"
const RADIO_ENABLED := &"radio_enabled"

## Share of each step the instrument is on, from 0 to 1.
var duty_cycle := 1.0
## Whether the radio transmits during contacts.
var radio_enabled := true


## initial returns the launch settings. The duty cycle comes from the design screen
## and the radio is on.
static func initial(input: SimInput) -> Controls:
	var c := Controls.new()
	c.duty_cycle = clampf(input.duty_cycle, 0.0, 1.0)
	return c


func value_of(control: StringName) -> Variant:
	match control:
		DUTY_CYCLE:
			return duty_cycle
		RADIO_ENABLED:
			return radio_enabled
	return null


## apply sets one control to a new value. It returns false for an unknown control
## and leaves the controls unchanged in that case.
func apply(control: StringName, value: Variant) -> bool:
	match control:
		DUTY_CYCLE:
			duty_cycle = clampf(float(value), 0.0, 1.0)
		RADIO_ENABLED:
			radio_enabled = bool(value)
		_:
			return false
	return true

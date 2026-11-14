class_name Controls
extends RefCounted
## The operational choices that stay open after launch. Everything else lives
## in SimInput and is locked once the mission flies.

const DUTY_CYCLE := &"duty_cycle"
const RADIO_ENABLED := &"radio_enabled"

## share of each step the instrument is on, 0..1
var duty_cycle := 1.0
## whether the radio transmits during contacts
var radio_enabled := true


## The settings the mission launches with: duty cycle from the design screen,
## radio on.
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


## Returns false for an unknown control, which leaves everything unchanged.
func apply(control: StringName, value: Variant) -> bool:
	match control:
		DUTY_CYCLE:
			duty_cycle = clampf(float(value), 0.0, 1.0)
		RADIO_ENABLED:
			radio_enabled = bool(value)
		_:
			return false
	return true

extends Node
## Global signals so screens can react to each other without holding references.
## Emit from whoever owns the change, listen from whoever draws it.

# yeah, nobody emits these in here, that is the whole point of a bus
@warning_ignore_start("unused_signal")
signal design_changed
signal margins_updated(margins: Dictionary)
signal role_signed_off(role: StringName, go: bool)
signal sim_tick(day: int)
signal event_fired(event_id: StringName)
signal screen_requested(screen: StringName)

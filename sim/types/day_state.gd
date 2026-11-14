class_name DayState
extends RefCounted
## Snapshot of the spacecraft at the end of one simulated day. The simulator
## returns one of these per day; the Simulation screen just plays them back.

var day := 0
var alive := true
var battery_wh := 0.0
var battery_capacity_wh := 0.0
## worst power balance seen during the day, negative means the battery was draining
var power_balance_w := 0.0
var data_stored_mb := 0.0
var data_downlinked_mb := 0.0
var science := 0.0
## event ids that fired on this day
var events: Array[StringName] = []
## why the mission ended, empty while alive. Used by the report.
var failure_reason := ""

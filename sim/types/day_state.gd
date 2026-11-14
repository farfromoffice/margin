class_name DayState
extends RefCounted
## Summary of one simulated day, folded out of a RunResult by RunResult.daily().
## The Simulation screen plays these back, the report lists them.

var day := 0
var energy_min_j := 0.0
var energy_end_j := 0.0
var stored_bits_end := 0.0
## bits delivered and discarded during this day only, not cumulative
var delivered_bits := 0.0
var discarded_bits := 0.0
var safe_time_s := 0.0
## RunResult.Mode at the end of the day
var mode_end := 0
## same dictionaries as RunResult.events, only the ones that fell on this day
var events: Array[Dictionary] = []

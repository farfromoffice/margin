class_name SimState
extends RefCounted


## Start time of the next step. It is always step times dt_s.
var t_s := 0.0
var step := 0
var total_steps := 0
var energy_j := 0.0
var stored_bits := 0.0
var mode := RunResult.Mode.NORMAL
var done := false
## Number of contact intervals that began during the last step. AutoPause reads it.
var contact_starts := 0
## The result, filled step by step. It is final once done is true.
var result := RunResult.new()

## Live failures. Health factors scale the design values, hangs block one part
## until the player power-cycles it. DESIGN.md has the rules.
var battery_health := 1.0
var solar_health := 1.0
var radio_hung := false
var instrument_hung := false
## Failure kinds that struck during the last step. AutoPause reads it.
var failures_started: Array[StringName] = []
## The failure plan of the run, sorted by t_s, and the next one still to strike.
var failures: Array[Dictionary] = []
var next_failure := 0


## Battery capacity left after any battery_fade.
func capacity_j(input: SimInput) -> float:
	return input.battery_capacity_j * battery_health

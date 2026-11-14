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

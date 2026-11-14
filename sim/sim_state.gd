class_name SimState
extends RefCounted


## start of the next step; always step * dt_s
var t_s := 0.0
var step := 0
var total_steps := 0
var energy_j := 0.0
var stored_bits := 0.0
var mode := RunResult.Mode.NORMAL
var done := false
## contact intervals that began during the last step, for the auto pause
var contact_starts := 0
## filled step by step; final once done is true
var result := RunResult.new()

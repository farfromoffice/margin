extends GutTest
## Tests that the mission clock turns real time into steps independent of the frame rate.


func _steps(clock: MissionClock, deltas: Array) -> int:
	var total := 0
	for d in deltas:
		total += clock.advance(d)
	return total


func _frames(seconds: float, fps: float) -> Array:
	var out := []
	for i in roundi(seconds * fps):
		out.append(1.0 / fps)
	return out


func test_one_mission_day_takes_six_seconds_at_1x_at_any_frame_rate() -> void:
	for fps in [30.0, 60.0, 144.0, 240.0]:
		assert_eq(_steps(MissionClock.new(), _frames(6.0, fps)), 1440, "%d fps" % fps)


func test_uneven_frames_give_the_same_steps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var weights := []
	var sum := 0.0
	for i in 500:
		var w := rng.randf_range(0.2, 3.0)
		weights.append(w)
		sum += w
	var deltas := weights.map(func(w): return 6.0 * w / sum)
	assert_eq(_steps(MissionClock.new(), deltas), 1440)


func test_speeds() -> void:
	for row in [[4, 1.5], [16, 0.375]]:
		var c := MissionClock.new()
		c.set_speed(row[0])
		# At 64 fps both durations are a whole number of frames.
		assert_eq(_steps(c, _frames(row[1], 64.0)), 1440, "%dx" % row[0])


func test_speed_change_keeps_the_count() -> void:
	var c := MissionClock.new()
	var steps := _steps(c, _frames(3.0, 60.0))
	c.set_speed(4)
	steps += _steps(c, _frames(0.75, 60.0))
	assert_eq(steps, 1440)


func test_paused_clock_runs_nothing() -> void:
	var c := MissionClock.new()
	c.set_paused(true)
	assert_eq(_steps(c, _frames(6.0, 60.0)), 0)
	c.set_paused(false)
	assert_eq(_steps(c, _frames(6.0, 60.0)), 1440)


func test_a_hitch_runs_at_most_a_day_and_does_not_catch_up() -> void:
	var c := MissionClock.new()
	assert_eq(c.advance(100.0), MissionClock.MAX_STEPS_PER_ADVANCE)
	assert_eq(c.advance(1.0 / 60.0), 4, "back to normal pace, the lost time stays lost")

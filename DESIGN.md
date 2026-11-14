# Design

Simulation contracts: data formats, state and rules the code and the research data must agree on. Implemented in `sim/` (Phase 1). Open questions are listed at the end with the default the code uses until the team settles them.

## Pipeline

```text
MissionDesign + Catalog -> SimInput (resolved numbers, SI)
                                │
orbit data + stations -> OrbitTimeline (eclipse and contact intervals)
                                │
                                ▼
                   Simulator: fixed 60 s steps  <- Controls (changed in flight, logged)
                                │
                                ▼
                RunResult (series, totals, events, commands, end reason)
                                │
                                ▼
                 report, charts, daily summaries (DayState)
```

`LaunchCheck` runs on the design and the catalog, `Warnings` on `SimInput` and the timeline, both before the simulation. All simulation code is pure `RefCounted` logic with no scene-tree access.

## Units

SI inside the simulation: s, W, J, bit, kg. Every identifier carries its unit as a suffix (`energy_j`, `rate_bps`). Data files may use other units only with a stating suffix (`capacity_wh`); `Catalog` adds an SI twin at load (`capacity_j`) and keeps the original for the UI. `SimInput` reads only the SI fields. "MB" in the UI means 10⁶ bytes.

| Data suffix | SI field | Factor |
|---|---|---|
| `_wh` | `_j` | 3600 |
| `_km` | `_m` | 1000 |
| `_days` | `_s` | 86400 |
| `_bytes` | `_bits` | 8 |
| `_mb` | `_bits` | 8·10⁶ |
| `_kbps`, `_mbps` | `_bps` | 10³, 10⁶ |

## Orbit data (`orbits.json`)

Added fields per orbit:

| Field | Type | Meaning |
|---|---|---|
| `altitude_km` | number | circular orbit altitude; period computed as `T = 2π√(a³/μ)`, `a = R_earth + altitude` |
| `eclipse_fraction` | number 0..1 | share of each orbit in Earth's shadow, from GMAT for the stated case |
| `reference_duration_s` | number | length of the GMAT window the contact data covers |
| `contacts_s` | object | ground station id → list of `[start_s, end_s]` pairs, relative to the window start, sorted, non-overlapping |
| `gmat_case` | string | id of the GMAT run in RESEARCH.md (epoch, Sun angle, minimum elevation) |

`tools/gmat/build_orbits.py` writes the last four fields from GMAT runs; ground stations carry `latitude_deg`, `longitude_deg`, `altitude_km` for it.

Constants: `μ = 3.986004418e14 m³/s²`, `R_earth = 6378137 m`.

## OrbitTimeline

Built once per run from the orbit entry, the chosen stations and `duration_s`:

- **Eclipses:** one interval per orbit, `[k·T + (1 − f)·T, (k + 1)·T)` for orbit `k`, until `duration_s`.
- **Contacts:** each chosen station's windows tiled every `reference_duration_s` until `duration_s`, then merged into one sorted list of non-overlapping intervals. Overlapping passes from two stations count once: there is one radio.
- Stored as `PackedFloat64Array` start/end pairs (float32 would lose about 0.25 s at 30 days).

Per step, the timeline answers with **overlap durations**, not booleans:

```text
step(t_s, dt_s) -> { sunlit_s, contact_s }   # seconds of [t, t+dt) in sunlight / in contact
```

Queries are monotonic, a cursor walks each list once per run. Overlap durations remove the 60 s quantization error at interval edges; a 6-minute pass is otherwise off by up to a third.

## SimInput

Resolved from `MissionDesign`, `Scenario` and `Catalog` before the run. Everything the simulator reads:

| Field | Source |
|---|---|
| `duration_s` | scenario `duration_s`, the SI twin Catalog adds for `duration_days` |
| `dt_s` | 60, fixed |
| `solar_power_w` | sum of solar `generated_w_1au × sunlit_factor` |
| `bus_power_w`, `bus_safe_power_w` | sums of `power_w` / `safe_power_w` over bus components except solar, comms and instruments |
| `instrument_power_w`, `instrument_rate_bps` | instrument entries |
| `duty_cycle` | `MissionDesign.instrument_duty_cycle`, 0..1, default 1. Only the starting value of the in-flight control; the simulator reads `Controls` |
| `radio_tx_power_w`, `radio_idle_power_w` | comms `power_w` / `safe_power_w` (summed if several) |
| `downlink_rate_bps` | comms `rate_bps` (fastest if several: one radio talks) |
| `battery_capacity_j` | sum of battery `capacity_j` |
| `safe_enter_fraction`, `safe_exit_fraction` | first battery entry; exit > enter |
| `storage_capacity_bits` | sum of obc `storage_bits` |
| `initial_energy_j` | `battery_capacity_j` (starts full) |

## State

`SimState` holds everything that changes during a run; `SimInput` (the launch configuration) never changes after launch.

```text
t_s, step, energy_j, mode (NORMAL | SAFE), stored_bits, done
result: RunResult being filled (totals, series, events, commands)
last step: contact_starts (contact intervals that began in it)
totals: generated_bits, delivered_bits, discarded_bits, missed_bits,
        safe_time_s, safe_entries
```

`missed_bits` is what the instrument would have produced while in Safe mode. It is not data, only the attribution of science lost to power; it is outside the data invariant.

## Controls

The two operational decisions the player can change in flight. Hardware, orbit and launcher stay locked after launch.

| Control | Type | Starts at | Effect |
|---|---|---|---|
| `duty_cycle` | float 0..1 | `SimInput.duty_cycle` (design screen) | instrument power and data generation, Normal mode only |
| `radio_enabled` | bool | `true` | whether the radio transmits during contacts, Normal mode only |

In Safe mode the instrument is off and the radio idles whatever the controls say; the values are kept and apply again once Normal resumes.

## Step rules

`Simulator.step(state, input, controls, timeline)` advances one step. Order is fixed. With `{sunlit_s, contact_s}` from the timeline, `dt = dt_s`, and `tx = contact_s` if `radio_enabled` else `0`:

1. **Loads by mode.**
   - Normal: `load_j = bus_power_w·dt + instrument_power_w·duty_cycle·dt + radio_tx_power_w·tx + radio_idle_power_w·(dt − tx)`
   - Safe: `load_j = bus_safe_power_w·dt + radio_idle_power_w·dt` (instrument off, no downlink)
2. **Battery.** `e = energy_j + solar_power_w·sunlit_s − load_j`. If `e < 0`: mission lost, end reason `POWER_LOST`, stop. Otherwise `energy_j = min(e, battery_capacity_j)`; surplus is not stored.
3. **Mode.** Normal and `energy_j ≤ enter·capacity` → Safe (`safe_entries += 1`, event). Safe and `energy_j ≥ exit·capacity` → Normal (event). Takes effect next step.
4. **Generation** (Normal only): `g = instrument_rate_bps·duty_cycle·dt`; `stored_bits += g`, `generated_bits += g`. In Safe: `missed_bits += instrument_rate_bps·duty_cycle·dt`, `safe_time_s += dt`.
5. **Downlink** (Normal only): `d = min(stored_bits, downlink_rate_bps·tx)`; `stored_bits −= d`, `delivered_bits += d`.
6. **Overflow:** if `stored_bits > storage_capacity_bits`, the excess is discarded (`discarded_bits += excess`), `stored_bits = storage_capacity_bits`. The bookkeeping treats the newest data as dropped.

Battery depletion ends the mission in either mode. With sane thresholds Normal mode reaches Safe long before zero. In practice this is the "can't sustain even the Safe load" case.

**Invariants** (tested every step in debug runs):

- `generated_bits = delivered_bits + discarded_bits + stored_bits`
- `0 ≤ energy_j ≤ battery_capacity_j · battery_health`, `0 ≤ stored_bits ≤ storage_capacity_bits`
- same inputs, same command log and same failure plan -> identical result (no randomness inside the simulator)

`Simulator.run(input, timeline, commands = [])` is a loop over `step()` that applies the logged commands at their step boundaries and never pauses. With no commands it is the uninterrupted mission and gives exactly the results of the pre-operations simulator.

## Live failures

Before launch `FailurePlan.generate(run_seed, duration_s, dt_s, failures.json rows)` draws the plan: 1 to 3 failures, each kind at most once, kind by `weight`, time uniform on a step boundary between 10 % and 90 % of the mission, magnitude uniform in `[magnitude_min, magnitude_max]`. The plan is a list `{t_s, kind, magnitude}` sorted by time. `run_seed` is drawn once per new mission, so flying a redesign meets the same failures at the same times. `GameState.live_failures` switches the draw off.

The simulator only replays the plan. At the start of each step every failure with `t_s ≤ t` strikes, is logged as a `failure` event and fires the `failure` auto-pause:

| Kind | Effect | Ends |
|---|---|---|
| `battery_fade` | `battery_health *= 1 − magnitude`; capacity, Safe thresholds and the full charge use `battery_capacity_j · battery_health`; charge above it is cut | never |
| `solar_loss` | `solar_health *= 1 − magnitude`; generation is `solar_power_w · solar_health · sunlit_s` | never |
| `radio_hang` | `tx = 0` (idle power only, no downlink) | after one whole step with `radio_enabled = false` |
| `instrument_hang` | instrument still draws its Normal-mode power, `step_gen = 0` (not counted as missed) | after one whole step with `duty_cycle = 0` or in Safe mode |

A hang that ends logs a `recovered` event at the end of that step. `Mission.power_cycle(control)` is the player's fix: it logs the switch off now and the switch back (radio on, or the previous duty cycle) after the next step, so the command log alone replays it. The no-intervention baseline flies the same plan with no commands, so a hang there lasts to the end. The rates and magnitudes are fictional teaching values; the weights follow the share of power-system and data-handling failures in the CubeSat surveys cited in failures.json.

## Commands

Every player change is logged as `{t_s, control, value}` in `RunResult.commands`. `t_s` is the step boundary at which the change was made (the simulation only stops between steps). A command applies from the step that starts at `t_s` onwards; several at the same `t_s` apply in log order. A change to the current value is not logged. Replaying the same `SimInput` with the same log through `Simulator.run()` reproduces the operated mission exactly.

## Mission clock

The simulation runs on a mission clock, decoupled from rendering:

| Speed | Mission time per real second | 30 day mission |
|---|---|---|
| 1× | 14,400 s (1 day per 6 s) | 180 s |
| 4× | 57,600 s | 45 s |
| 16× | 230,400 s | 11.25 s |

Each frame adds `real_delta × rate` to a time debt and runs `floor(debt / dt_s)` steps, keeping the remainder, so the step count depends only on elapsed real time, not on the frame rate. At most one mission day of steps (1440) runs per frame; debt beyond that is dropped, so a frame hitch never fast-forwards the mission. Pausing clears the debt. The UI redraws once per frame, never per step.

## Auto-pause

Checked after every simulation step, never per frame. When one fires, the step that triggered it completes, the remaining steps of that frame are not run and the clock pauses. Each trigger fires on a crossing, not while a condition stays true, and re-arms only after recovering past a separate level:

| Trigger | Default | Fires when | Re-arms when |
|---|---|---|---|
| `low_battery` | on | in Normal mode, charge falls to `min(enter + 0.10, exit) · capacity` | charge ≥ `exit · capacity`, at least one mission day after it last fired |
| `storage_high` | on | stored data rises to ≥ 80 % of storage | stored data < 60 % of storage |
| `contact_begin` | on | a contact begins in a Normal-mode step while the radio is off | the radio control is changed |
| `safe_enter` | off | Safe mode is entered (always logged as an event) | next entry |
| `failure` | on | a planned failure struck in the step | each kind strikes once |

Two choices here go beyond the brief, and both are teaching values the team can tune:

- **The low-battery pause sits above Safe-mode entry.** In Safe mode the instrument is already off and the radio idles, so neither control changes the power draw: a pause there offers no decision. Pausing 10 points above the Safe threshold gives the player a chance to lower the duty cycle or switch the radio off before Safe mode takes over.
- **The low-battery pause has a one-day cooldown.** A weak power design cycles through Safe mode several times a day; re-arming on every recharge gave 226 pauses in one 30-day test mission (one every 0.8 s at 1×). With the cooldown it stops at most once per mission day.
- **Contact pauses only happen while the radio is off.** The reference design sees about 18 passes a day (527 in 30 days, one every 0.34 s at 1×). With the radio on, transmitting is already the decision. With it off, each new pass is a real choice; after one pause the trigger stays quiet until the player changes the radio again, so leaving it off doesn't interrupt every orbit.

A pause opens a decision panel in place of the mission log (the charts may shrink while it is open). It holds:

- the reason, with what broke and how to fix it for a failure;
- the numbers behind the problem (`Explain.tradeoffs`): how many Wh per orbit the power is short, or what the camera makes against what the radio can send per day, and the exchange rate from `Warnings.camera_step`, the energy per orbit and the data per day of 10 % of camera time;
- where the mission ends up with the controls as they are now, if nothing else breaks: the goal margin and any coming Safe mode or full memory;
- the switches and repairs from `Warnings.choices(fired, input, timeline, controls, state)`, each with its effect, and Resume.

The panel never names a camera time. How far to turn the camera down trades pictures against power or memory, and the best answer is not always the one that balances the battery: a camera run past that point can still send more, Safe mode cycles and all. The player sets the slider (its effect lines preview the value under the thumb), the panel refreshes with the new outcome, and Resume runs the clock at the last speed. Options, `{kind, value}`:

| Reason | Option | When |
|---|---|---|
| `failure` | restart the radio or the camera | that part is hung (the camera only when its time is above 0) |
| `low_battery`, `safe_enter` | radio off | power is short every orbit and the radio is on; it saves transmit power and sends nothing |
| `storage_high`, `contact_begin` | radio on | it is off and not hung (a hung radio comes back on with its restart) |

## Forecast

When a control changes (and once per mission day), the operations screen shows an estimate for the rest of the mission from the current state, using the same averages as the warnings: energy per orbit, data generated and sendable per day, time until storage is full, time until Safe mode, all under the current controls. These are averages over orbits and passes, not a run of the simulator, and the UI labels them as estimates. The energy per orbit and the data per day sit under the camera slider and the radio switch, and the slider line follows the thumb while it is dragged, before anything is applied. Each change is logged with its energy per orbit and goal projection before and after.

**Goal projection.** `Warnings.projected_delivered_bits` is the data at home at the end if the controls stay as they are: what is home, plus what the radio can still send, capped by what is stored and what the camera still makes. When the battery drains every orbit, the spacecraft cycles between Normal and Safe mode after the first Safe mode: it drains from the exit to the entry level in Normal and charges back across the same span in Safe, with the camera off and the radio silent. Both then work for `normal_share = charge / (charge − net)` of the time, where charge is the Safe mode energy gain per orbit. A frozen camera clears on its first Safe mode step, from then on it is counted at its normal output. The radio's capacity is capped per phase, before and after the first Safe mode, since pass time with nothing to send is lost. Against 400 random launchable Wildfire Watch designs flown without failures, the projection at launch is within 1.8 % of the real run for 90 % of them and agrees on goal met or missed for 399. The operations screen shows the goal line and percentage, and the estimate as a margin against the goal ("about 108,000 MB, 8 % above the goal"), rounded to whole thousands and always with its assumptions: the settings stay as they are and nothing else breaks. The failures still planned for the mission are not in it.

## No-intervention baseline

When the mission ends, the same `SimInput` is run again with no commands: the design flown with its launch settings and never touched. The report compares the operated mission with it: data delivered, data discarded, Safe-mode time, mission completion and the objectives. A difference counts only beyond `max(8·10⁶ bit, 0.1 % of the baseline)`; anything smaller is reported as "the same". With no commands the two runs are identical and the report says so instead of claiming an effect.

## What held the mission back

The report explains each limiting factor with the run's own numbers (`Outcome.factor_numbers`): Safe mode entries and time, pictures never taken and the energy per orbit at the launch settings for power; memory size, data thrown away, camera output and radio capacity per day for storage; pass minutes per day, radio capacity, camera output and the data left behind for downlink. Each also names what it depends on in the design, as facts. Then it says where the factor came from by comparing two whole flights: if the no-intervention baseline hit it too, it comes from the design; if only the flown mission did, from the changes in flight; a factor only the baseline hit is listed as avoided.

There is deliberately no effect per change. Replaying the flight without one change, keeping the others, was tested on 120 random missions with planned failures and 2 to 5 random changes each: for changes worth over 1 % of the data it agreed in sign with adding that change alone to the untouched flight only 58 % of the time, and the per-change effects missed the total by a median 22 % (over 100 % for one mission in ten). Changes depend on each other (radio off, later back on; camera down, later up), so a split per change would read as exact when it is not.

## Design comparison

From the second flight of a mission on, the report puts the last flight and this one side by side. `GameState.finish_mission` keeps a copy of the flown design next to each result (`last_design`, `previous_design`), since the design screen edits `design` in place. `DesignCompare.rows(before, after, catalog)` returns one row per choice, `{key, before, after, changed}`: orbit, launcher, each part category, ground stations (sorted names, so order does not count), duty cycle, then total mass and cost. Changed rows are highlighted. The result rows reuse `Outcome.compare_runs` with the earlier flight as the baseline, so the same threshold decides what counts as a difference. Failures are not part of the comparison: both flights meet the same plan from the mission seed.

## RunResult

```text
end_reason: COMPLETED | POWER_LOST, end_t_s
series (one value per step, PackedFloat64Array / PackedByteArray):
    energy_j, stored_bits, delivered_bits and discarded_bits (cumulative), mode
totals: as in State
events: [{t_s, kind: safe_enter | safe_exit | power_lost | failure | recovered, energy_j}]
        failure and recovered also carry `failure` (the kind), failure carries `magnitude`
commands: [{t_s, control, value}]
failures: the plan the run met
```

At 30 days that is 43,200 steps per series. The UI downsamples for charts. `RunResult.daily()` folds the series into one `DayState` per day: `energy_min_j`, `energy_end_j`, `stored_bits_end`, `delivered_bits` and `discarded_bits` of that day, `safe_time_s`, `mode_end`, the day's events.

## LaunchCheck

Runs on the design before simulation. Returns a list of violations `{kind, value, limit, unit}`; any violation blocks launch.

| Kind | Rule |
|---|---|
| `missing_part` | no structure, solar, battery, comms, obc, instrument, ground station or launcher; `value` names it |
| `unknown_component` | a chosen id is not in the catalog |
| `orbit_not_allowed` | scenario `allowed_orbit_ids` is not empty and lacks the orbit |
| `orbit_unreachable` | launcher `capacity_kg` has no entry for the orbit |
| `structure_too_small` | a part's `min_structure_u` is above the structure's `volume_u`; `value` is the part id, `limit` the size it needs (the 6U deployable array needs 6U) |
| `over_structure_payload` | mass of every part except the structure > the structure's `max_payload_kg` (when it has one) |
| `over_launcher_capacity` | total mass > `capacity_kg[orbit_id]` |
| `over_scenario_mass` | total mass > scenario `max_mass_kg` (when > 0) |
| `over_budget` | hardware plus launcher cost > scenario `budget_kusd` (when > 0) |

Total mass is the sum of all chosen components and instruments. For kinds without a number `value` holds the id or category and `limit` is null.

## Warnings

Computed before the run from `SimInput` and the timeline. The prediction screen and report can compare against them. Each is `{kind, value, limit, unit}`; none blocks launch.

| Kind | Rule |
|---|---|
| `orbit_energy_negative` | Normal-mode energy over one orbit at the given eclipse fraction is negative, using average contact time per orbit |
| `downlink_short` | data generated per day > `downlink_rate_bps` × average contact seconds per day |
| `storage_fills` | backlog per day > 0 and storage fills before mission end; `value` is the fill time in s |
| `camera_unpointed` | the design has a camera and no pointing system; `value` is `SimInput.UNPOINTED_SHARE` |

## Code layout

```text
sim/orbit_timeline.gd    OrbitTimeline
sim/sim_input.gd         SimInput.from_design(design, scenario, catalog)
sim/simulator.gd         Simulator.start/step/run
sim/controls.gd          Controls (duty_cycle, radio_enabled)
sim/sim_state.gd         SimState
sim/mission_clock.gd     MissionClock: real time -> step count
sim/auto_pause.gd        AutoPause: triggers, arming
sim/mission.gd           Mission: state + controls + command log + auto-pause + power cycle
sim/failure_plan.gd      FailurePlan.generate(seed, duration_s, dt_s, entries)
sim/launch_check.gd      LaunchCheck.check(design, scenario, catalog) -> violations
sim/design_compare.gd    DesignCompare.rows(before, after, catalog) -> one row per choice
sim/warnings.gd          Warnings.compute(input, timeline) -> warnings
sim/types/run_result.gd  RunResult
sim/types/day_state.gd   daily summary
tools/gmat/              GMAT case generator for orbits.json
tools/balance.gd         flies every valid Wildfire Watch design, CSV for the balance table
```

## Open questions

Each one lists the default the code uses today.

1. **Eclipse source.** Synthetic placement from `eclipse_fraction` (current rule) ignores the real phase between eclipses and contacts. GMAT can export eclipse intervals the same way as contacts (the generator already runs an `EclipseLocator`), which would make both lists identical in form and drop the synthetic step. Needs a team decision. *Default: synthetic.*
2. **Solar generation.** *Settled:* each solar entry has a `sunlit_factor` (0..1, `approximation`), the average share of `generated_w_1au` delivered over a sunlit arc. Values and reasoning in RESEARCH.md.
3. **Storage field.** *Settled:* `storage_bytes` on obc entries, documented in data/README.md.
4. **Duty cycle.** Averaged over every step vs. instrument on only in sunlight (realistic for visible imagers, not for thermal). *Default: averaged.*
5. **Budget scope.** Hardware and launcher only, or also ground station cost per pass (known only after the run). *Default: hardware and launcher.* Tied to the open cost model.
6. **Objective evaluation.** How `delivered_bits` maps to the scenario objective (bits, or observations of a fixed size) depends on the results decision. Wildfire Watch carries a placeholder `delivered_mb` objective. The goal is 100,000 MB, a fictional teaching value chosen from a sweep of 5,184 launchable designs. At 20,000 MB half of them passed, including a design that never came near any limit and the battery and downlink never mattered. At 100,000 MB about 28 % pass, with all three cameras and with both S-band and X-band. The comfortable design at 20 % camera time fails and passes again at 35 %. Pushing the camera further with S-band throws data away at the downlink limit and the power hungry designs lose time in Safe mode.
7. **Performance.** *Settled:* a 30 day run (43,200 steps) takes about 0.2 s in a debug build with invariant checks on.
8. **Operations tuning.** Auto-pause levels (low battery 10 points above Safe entry, storage 80 % / 60 %) and the clock rates are teaching values, to be adjusted after the first playtest. *Default: as in Auto-pause and Mission clock.*

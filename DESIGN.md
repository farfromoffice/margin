# Design

Simulation contracts: data formats, state and rules the code and the research data must agree on. **Draft**: nothing here is implemented yet. Open questions are listed at the end; do not build on them until they are settled.

## Pipeline

```text
MissionDesign + Catalog -> SimInput (resolved numbers, SI)
                                │
orbit data + stations -> OrbitTimeline (eclipse and contact intervals)
                                │
                                ▼
                   Simulator: fixed 60 s steps
                                │
                                ▼
                RunResult (series, totals, events, end reason)
                                │
                                ▼
                 report, charts, daily summaries (DayState)
```

`LaunchCheck` and `Warnings` run on `SimInput` before the simulation. All simulation code is pure `RefCounted` logic with no scene-tree access.

## Units

SI inside the simulation: s, W, J, bit, kg. Every identifier carries its unit as a suffix (`energy_j`, `rate_bps`). Data files may use other units only with a stating suffix (`capacity_wh`); `SimInput` converts once. "MB" in the UI means 10⁶ bytes.

## Orbit data (`orbits.json`)

Added fields per orbit:

| Field | Type | Meaning |
|---|---|---|
| `altitude_km` | number | circular orbit altitude; period computed as `T = 2π√(a³/μ)`, `a = R_earth + altitude` |
| `eclipse_fraction` | number 0..1 | share of each orbit in Earth's shadow, from GMAT for the stated case |
| `reference_duration_s` | number | length of the GMAT window the contact data covers |
| `contacts_s` | object | ground station id → list of `[start_s, end_s]` pairs, relative to the window start, sorted, non-overlapping |
| `gmat_case` | string | id of the GMAT run in RESEARCH.md (epoch, Sun angle, minimum elevation) |

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
| `duration_s` | scenario `duration_days` |
| `dt_s` | 60, fixed |
| `solar_power_w` | sum of solar `generated_w_1au` (see open question 2) |
| `bus_power_w`, `bus_safe_power_w` | sums of `power_w` / `safe_power_w` over bus components except comms and instruments |
| `instrument_power_w`, `instrument_rate_bps` | instrument entries |
| `duty_cycle` | `MissionDesign.instrument_duty_cycle`, 0..1 (new field) |
| `radio_tx_power_w`, `radio_idle_power_w` | comms `power_w` / `safe_power_w` |
| `downlink_rate_bps` | comms `rate_bps` |
| `battery_capacity_j` | battery `capacity_wh` × 3600 |
| `safe_enter_fraction`, `safe_exit_fraction` | battery entry; exit > enter |
| `storage_capacity_bits` | obc `storage_bytes` × 8 (new field) |
| `initial_energy_j` | `battery_capacity_j` (starts full) |

## State

```text
t_s, energy_j, mode (NORMAL | SAFE), stored_bits
totals: generated_bits, delivered_bits, discarded_bits, missed_bits,
        safe_time_s, safe_entries
```

`missed_bits` is what the instrument would have produced while in Safe mode. It is not data, only the attribution of science lost to power; it is outside the data invariant.

## Step rules

Order is fixed. With `{sunlit_s, contact_s}` from the timeline and `dt = dt_s`:

1. **Loads by mode.**
   - Normal: `load_j = bus_power_w·dt + instrument_power_w·duty_cycle·dt + radio_tx_power_w·contact_s + radio_idle_power_w·(dt − contact_s)`
   - Safe: `load_j = bus_safe_power_w·dt + radio_idle_power_w·dt` (instrument off, no downlink)
2. **Battery.** `e = energy_j + solar_power_w·sunlit_s − load_j`. If `e < 0`: mission lost, end reason `POWER_LOST`, stop. Otherwise `energy_j = min(e, battery_capacity_j)`; surplus is not stored.
3. **Mode.** Normal and `energy_j ≤ enter·capacity` → Safe (`safe_entries += 1`, event). Safe and `energy_j ≥ exit·capacity` → Normal (event). Takes effect next step.
4. **Generation** (Normal only): `g = instrument_rate_bps·duty_cycle·dt`; `stored_bits += g`, `generated_bits += g`. In Safe: `missed_bits += instrument_rate_bps·duty_cycle·dt`, `safe_time_s += dt`.
5. **Downlink** (Normal only): `d = min(stored_bits, downlink_rate_bps·contact_s)`; `stored_bits −= d`, `delivered_bits += d`.
6. **Overflow:** if `stored_bits > storage_capacity_bits`, the excess is discarded (`discarded_bits += excess`), `stored_bits = storage_capacity_bits`. The bookkeeping treats the newest data as dropped.

Battery depletion ends the mission in either mode. With sane thresholds Normal mode reaches Safe long before zero. In practice this is the "can't sustain even the Safe load" case.

**Invariants** (tested every step in debug runs):

- `generated_bits = delivered_bits + discarded_bits + stored_bits`
- `0 ≤ energy_j ≤ battery_capacity_j`, `0 ≤ stored_bits ≤ storage_capacity_bits`
- same inputs -> identical result (no randomness)

## RunResult

```text
end_reason: COMPLETED | POWER_LOST, end_t_s
series (one value per step, PackedFloat64Array / PackedByteArray):
    energy_j, stored_bits, delivered_bits (cumulative), mode
totals: as in State
events: [{t_s, kind: safe_enter | safe_exit | power_lost, energy_j}]
```

At 30 days that is 43,200 steps per series. The UI downsamples for charts; `DayState` becomes a daily summary derived from the series (energy min/end, data delivered and discarded that day, safe time, events), replacing its current fields.

## LaunchCheck

Runs on the design before simulation. Returns a list of violations `{kind, value, limit, unit}`; any violation blocks launch.

| Kind | Rule |
|---|---|
| `orbit_unreachable` | launcher `capacity_kg` has no entry for the orbit |
| `over_launcher_capacity` | total mass > `capacity_kg[orbit_id]` |
| `over_scenario_mass` | total mass > scenario `max_mass_kg` (when > 0) |
| `over_budget` | total cost > scenario budget (which costs count: open question 5) |

Total mass is the sum of all chosen components and instruments.

## Warnings

Computed before the run from `SimInput` and the timeline. The prediction screen and report can compare against them. Each is `{kind, value, limit, unit}`; none blocks launch.

| Kind | Rule |
|---|---|
| `orbit_energy_negative` | Normal-mode energy over one orbit at the given eclipse fraction is negative, using average contact time per orbit |
| `downlink_short` | data generated per day > `downlink_rate_bps` × average contact seconds per day |
| `storage_fills` | backlog per day > 0 and storage fills before mission end |

## Code layout

```text
sim/orbit_timeline.gd    OrbitTimeline
sim/sim_input.gd         SimInput.from_design(design, scenario, catalog)
sim/simulator.gd         Simulator.run(input, timeline) -> RunResult
sim/launch_check.gd      LaunchCheck.check(design, scenario, catalog) -> violations
sim/warnings.gd          Warnings.compute(input, timeline) -> warnings
sim/types/run_result.gd  RunResult
sim/types/day_state.gd   daily summary
```

## Open questions

1. **Eclipse source.** Synthetic placement from `eclipse_fraction` (current rule) ignores the real phase between eclipses and contacts. GMAT can export eclipse intervals the same way as contacts, which would make both lists identical in form and drop the synthetic step. Needs a team decision.
2. **Solar generation.** `generated_w_1au` is output facing the Sun. Average output over a sunlit arc depends on pointing; a fixed orientation factor (`approximation`) is likely needed. Value and source open.
3. **Storage field.** `storage_bytes` on the obc component is a schema addition; data/README needs it.
4. **Duty cycle.** Averaged over every step (current rule) vs. instrument on only in sunlight (realistic for visible imagers, not for thermal). Depends on the instrument type chosen in research.
5. **Budget scope.** Hardware and launcher only, or also ground station cost per pass (known only after the run). Tied to the open cost model.
6. **Objective evaluation.** How `delivered_bits` maps to the scenario objective (bits, or observations of a fixed size) depends on the results decision.
7. **Performance.** 43,200 steps is assumed cheap in GDScript; measure once the loop exists.

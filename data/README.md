# Game data

Everything the game knows about parts, rockets, orbits and missions lives in these JSON files. Edit them without touching code; `Catalog` (`autoload/catalog.gd`) loads them at startup and skips entries that are missing required fields, with a warning in the output.

Entries marked `"placeholder": true` are only there to show the shape and must be replaced before the demo.

## Provenance

Every numeric entry needs a `source` field (URL or document plus page and date) and a `provenance` label.

- `documented`: published value, taken as is;
- `approximation`: simplified or derived from documented values; RESEARCH.md records how;
- `fictional`: a teaching value, stated openly.

## Units

The simulation works in SI: bits, seconds, watts, joules, kilograms.

- Every numeric field names its unit as a suffix: `mass_kg`, `power_w`, `capacity_wh`, `rate_bps`, `duration_days`.
- A file may use a non-SI unit only when the suffix states it. `Catalog` converts to SI once at load; no other code converts. *(Conversion at load is planned, not implemented yet.)*
- MB means decimal megabytes (10⁶ bytes). Binary units (MiB) are not used.
- Cost fields keep `cost_kusd` until the cost model is decided.

## components.json

| Field | Type | Notes |
|---|---|---|
| id | string | unique |
| name | string | shown in the UI |
| category | string | structure, solar, battery, comms, obc, adcs, instrument |
| tier | string | simple or advanced |
| mass_kg, cost_kusd | number | |
| power_w | number | draw in Normal mode while on |
| safe_power_w | number | draw in Safe mode; 0 for instruments |
| source, provenance | string | see Provenance |

Category specific fields:

| Category | Fields |
|---|---|
| solar | generated_w_1au (output at Earth distance, facing the Sun) |
| battery | capacity_wh, safe_enter_fraction, safe_exit_fraction (state of charge thresholds, exit above enter) |
| comms | band, rate_bps (usable downlink rate during a contact) |
| structure | volume_u (CubeSat units), max_payload_kg |
| instrument | data_rate_bps (generation rate while on) |

Component reliability is not modeled in the first version.

## launchers.json

id, name, cost_kusd, capacity_kg (object: orbit id to kg; an orbit missing here is unreachable by this launcher), source, provenance.

## orbits.json

id, name, body (earth), altitude_km, inclination_deg, explain (one or two plain sentences for the tooltip), source, provenance.

Eclipse fraction and contact windows per ground station come from offline GMAT runs. Their field layout is defined in DESIGN.md once it exists.

## scenarios.json

Matches `sim/types/scenario.gd`: id, title, briefing, difficulty, duration_days (default mission length 30; the engine takes it as input), budget_kusd, max_mass_kg, allowed_orbit_ids, critical_resources, objectives, sandbox.

## ground_stations.json

id, name, network (e.g. near earth, DSN), min_elevation_deg, cost_kusd_per_pass, g_over_t_dbk, source, provenance.

## real_missions.json

id, name, year, orbit_id, summary, url. Used for the "closest real mission" card on the report.

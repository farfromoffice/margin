# Game data

Everything the game knows about parts, rockets, orbits and missions lives in these JSON files. Edit them without touching code; `Catalog` (`autoload/catalog.gd`) loads them at startup and skips entries that are missing required fields, with a warning in the output.

Entries marked `"placeholder": true` are only there to show the shape and must be replaced before the demo.

## Provenance

Every numeric entry needs a `source` field (URL or document plus page and date) and a `provenance` label. `Catalog` skips entries in components, launchers, orbits and ground_stations that lack either, or use a label not listed below.

- `documented`: published value, taken as is;
- `approximation`: simplified or derived from documented values; RESEARCH.md records how;
- `fictional`: a teaching value, stated openly.

`provenance` labels the entry as a whole. When single values are weaker or stronger than that, `provenance_fields` overrides them per field, e.g. `"provenance_fields": { "cost_kusd": "fictional" }`. Costs are fictional across the catalog until the cost model is decided.

## Units

The simulation works in SI: bits, seconds, watts, joules, kilograms.

- Every numeric field names its unit as a suffix: `mass_kg`, `power_w`, `capacity_wh`, `rate_bps`, `duration_days`.
- A file may use a non-SI unit only when the suffix states it. `Catalog` converts to SI once at load and stores the result next to the original (`capacity_wh` gets a `capacity_j`); no other code converts. The suffix table is in DESIGN.md.
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
| model | string | how the 3D preview draws it (`ui/spacecraft/spacecraft_model.gd`); unknown or missing falls back to the category default |

Category specific fields:

| Category | Fields |
|---|---|
| solar | generated_w_1au (output at Earth distance, facing the Sun), sunlit_factor (0..1, average share of that over a sunlit arc; 1 when missing) |
| battery | capacity_wh, safe_enter_fraction, safe_exit_fraction (state of charge thresholds, exit above enter) |
| comms | band, rate_bps (usable downlink rate during a contact). power_w is the draw while transmitting, safe_power_w while listening |
| obc | storage_bytes (mass storage for science data) |
| structure | volume_u (CubeSat units), max_payload_kg |
| instrument | data_rate_bps (generation rate while on) |

Component reliability is not modeled in the first version.

## launchers.json

id, name, cost_kusd, capacity_kg (object: orbit id to kg; an orbit missing here is unreachable by this launcher), source, provenance.

## orbits.json

id, name, body (earth), altitude_km, inclination_deg, explain (one or two plain sentences for the tooltip), gmat_case, source, provenance.

eclipse_fraction, reference_duration_s and contacts_s are written by `tools/gmat/build_orbits.py` from GMAT runs; do not edit them by hand. Field layout in DESIGN.md, the cases in RESEARCH.md.

## scenarios.json

Matches `sim/types/scenario.gd`: id, title, briefing, difficulty, duration_days (default mission length 30; the engine takes it as input), budget_kusd, max_mass_kg, allowed_orbit_ids, critical_resources, objectives, sandbox.

## ground_stations.json

id, name, network (e.g. near earth, DSN), latitude_deg, longitude_deg (east positive), altitude_km, min_elevation_deg, cost_kusd_per_pass, g_over_t_dbk (optional), source, provenance. After changing a station, rerun the GMAT generator.

## real_missions.json

id, name, year, orbit_id, summary, url. Used for the "closest real mission" card on the report.

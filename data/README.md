# Game data

Everything the game knows about parts, rockets, orbits and missions lives in these JSON files. Edit them without touching code; `Catalog` (`autoload/catalog.gd`) loads them at startup and skips entries that are missing required fields, with a warning in the output.

Every entry needs a `source` field (URL or document plus page). RESEARCH.md lists the sources. Entries marked `"placeholder": true` are only there to show the shape and must be replaced before the demo.

Units: mass in kg, power in W, energy in Wh, money in thousands of USD (kusd), data in MB, rates in kbps, distances in km.

## components.json

| Field | Type | Notes |
|---|---|---|
| id | string | unique |
| name | string | shown in the UI |
| category | string | structure, solar, battery, comms, obc, adcs, propulsion, instrument |
| tier | string | simple or advanced |
| mass_kg, power_w, cost_kusd | number | power_w is consumption while on |
| reliability | number | 0 to 1, chance it survives the mission |
| source | string | |

Category specific fields:

| Category | Fields |
|---|---|
| solar | generated_w_1au (output at Earth distance, facing the Sun) |
| battery | capacity_wh |
| comms | band, data_rate_kbps, eirp_dbw |
| structure | volume_u (CubeSat units), max_payload_kg |
| propulsion | delta_v_mps for the default spacecraft mass, isp_s, propellant_kg |
| instrument | data_mb_per_day, science_per_day, requires_orbit (optional list) |

## launchers.json

id, name, cost_kusd, capacity_kg (object: orbit id to kg), reliability, source.

## orbits.json

id, name, body (earth, moon, mars), altitude_km, inclination_deg, explain (one or two plain sentences for the tooltip), source.

## scenarios.json

Matches `sim/types/scenario.gd`: id, title, briefing, difficulty, duration_days, budget_kusd, max_mass_kg, allowed_orbit_ids, critical_resources, objectives, sandbox.

## ground_stations.json

id, name, network (e.g. near earth, DSN), min_elevation_deg, cost_kusd_per_pass, g_over_t_dbk, source.

## real_missions.json

id, name, year, orbit_id, summary, url. Used for the "closest real mission" card on the report.

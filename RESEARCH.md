# Research

Everything the game simulates is simplified on purpose. This file says what we simplified, where each number comes from, and how we checked it.

## Official challenge resources and how Margin uses them

| Resource | Used for |
|---|---|
| [Design and Develop Science Missions](https://www.nasa.gov/wp-content/uploads/2025/04/250323-design-and-develop-science-mission.pdf) | The four mission segments (launch, space, ground, user) become the four tabs of the Design screen |
| [Concept Maturity Levels](https://dataverse.jpl.nasa.gov/dataset.xhtml?persistentId=hdl:2014/44299) (JPL) | Game progression: CML 1 idea, CML 2 feasibility, CML 3 trade study, CML 4 point design, then launch |
| [Mission Design Lab](https://etd.gsfc.nasa.gov/capabilities/integrated-design-center/mission-design-lab/) (GSFC) | Trade Study screen for comparing designs side by side |
| [A Learning Game About Telescopes](https://science.nasa.gov/mission/webb/game-build-it-yourself/) | Report shows the real NASA mission closest to the player's design |
| [CubeSat 101](https://www3.nasa.gov/sites/default/files/atoms/files/nasa_csli_cubesat_101_508.pdf) | Component catalog, CubeSat form factors, tutorial wording |
| [GMAT](https://software.nasa.gov/software/GSC-19468-1) | Offline check of orbit numbers (period, eclipse, contact time) |
| [NASA Mission Viz](https://nasa.github.io/mission-viz/) | Visual reference for the orbit view |
| [CSA Digital Games and Activities](https://www.asc-csa.gc.ca/eng/youth-educators/digital-games-and-activities.asp) | Tone and difficulty reference for young players |

## Models

Contracts and step rules are in DESIGN.md; this section says where the numbers come from and what we left out.

### Orbit (`sim/orbit_timeline.gd`)

Circular orbits only. Period from `T = 2π√(a³/μ)` with `μ = 3.986004418e14 m³/s²` and `R_earth = 6378137 m` (WGS 84). Eclipses are placed synthetically, one per orbit, from the GMAT eclipse fraction (DESIGN.md open question 1). Contact windows come from GMAT for a 7 day reference window and repeat every 7 days. Overlapping passes over two stations count once, since the spacecraft has one radio.

Left out: drag and orbit decay, seasonal change of the eclipse fraction, link budgets per pass (a contact either carries the full `rate_bps` or nothing), band compatibility between radio and station.

### GMAT cases (`tools/gmat/build_orbits.py`)

GMAT R2025a console, JGM 3 gravity 4×4, RK89, 10 s locator step, no light time or aberration. Shadow counts umbra plus penumbra, which is conservative by about 20 s per orbit. Stations use the ellipsoid horizon and a 10° minimum elevation. The generated scripts are in `tools/gmat/cases/`.

| Case | Epoch (UTC) | Window | Orbit | RAAN | Eclipse | Contact per day (Svalbard / Fairbanks / Wallops) |
|---|---|---|---|---|---|---|
| `leo_400_2027_07` | 1 Jul 2027 00:00 | 7 d | 400 km, 51.6° | 0° | 38.3 % | 0 / 0 / 1369 s |
| `sso_550_2027_07` | 1 Jul 2027 00:00 | 7 d | 550 km, 97.6° | 77.27° (LTAN 10:30) | 35.9 % | 4636 / 2500 / 1347 s |
| `sso_700_2027_07` | 1 Jul 2027 00:00 | 7 d | 700 km, 98.2° | 77.27° (LTAN 10:30) | 34.3 % | 5752 / 3880 / 1657 s |

RAAN for the sun-synchronous cases is the Sun's right ascension at the epoch (low precision formula from the Astronomical Almanac) minus 1.5 h of hour angle. The ISS-like orbit never rises 10° over Svalbard or Fairbanks: at 400 km the 10° footprint reaches about 12.7° of latitude past the 51.6° ground track, short of Fairbanks at 64.9° N. The game keeps that on purpose, it is the cheapest orbit and the worst for polar stations.

### Power and modes (`sim/simulator.gd`)

Energy balance per 60 s step: solar input during the sunlit part of the step, loads by mode, battery clamped to capacity, mission lost below zero. Safe mode turns off the instrument and the transmitter and drops the bus to `safe_power_w`.

`sunlit_factor` turns the Sun facing peak `generated_w_1au` into an average over a sunlit arc:

- four body-mounted side panels on a nadir pointing CubeSat: peak `generated_w_1au` is two panels at 45°, `8.4·√2 = 11.9 W`; the average of `|cos θ| + |sin θ|` over a turn is `4/π`, so the factor is `(4/π)/√2 ≈ 0.9`. Sun out of the orbit plane (beta angle) is ignored;
- deployable arrays: 0.7 (a fixed array is Sun facing only part of the arc, our estimate).

Safe mode thresholds (enter at 30 %, leave at 60 % state of charge) are teaching values. Left out: battery efficiency and depth of discharge wear, temperature, degradation.

### Data chain (`sim/simulator.gd`)

The instrument produces `data_rate_bps × duty_cycle` on average every step in Normal mode. Downlink empties storage at `rate_bps` while in contact. Data over the storage limit is discarded. `generated = delivered + discarded + stored` is checked every step in debug builds and in the tests. Instrument data rates are our estimates (vendors publish sensor format, not stream rates).

### Launch check and warnings (`sim/launch_check.gd`, `sim/warnings.gd`)

Mass and budget are plain sums. Budget counts hardware and launcher, not ground station passes (DESIGN.md open question 5). Warnings use orbit averages in Normal mode and do not model Safe mode.

## Data sources

Every entry in `data/` carries its own `source` and `provenance`; per field labels are in `provenance_fields`. Summary for the Wildfire Watch catalog:

| Table | Documented | Approximation | Fictional |
|---|---|---|---|
| components | masses and powers from EnduroSat, GomSpace, CubeSpace, Simera Sense and Fraunhofer ERNST pages | usable radio rates, instrument data rates, `sunlit_factor`, safe mode draws, some masses | all costs, safe mode thresholds |
| launchers | SpaceX rideshare price and SSO slot, Electron price, CSLI no cost | Electron capacity to 700 km, 12 kg CSLI limit (6U CubeSat spec) | |
| orbits | | GMAT runs above | |
| ground_stations | NASA Near Space Network sites | rounded coordinates, 10° minimum elevation | cost per pass |

The usable radio rate is set well below the vendor's gross maximum (UHF 9.6 of 19.6 kbps, S-band 5 of 20 Mbps, X-band 50 of 150 Mbps) to stand in for link margin with small ground antennas.

## Validation

| Check | Expected | Margin | Source |
|---|---|---|---|
| LEO 400 km orbital period | ~92 min | 92.6 min | GMAT, `T = 2π√(a³/μ)` |
| LEO 400 km eclipse fraction | ~35 to 40 % | 38.3 % | GMAT |
| SSO 550 km eclipse fraction, LTAN 10:30 | ~35 % | 35.9 % | GMAT |
| SSO 550 km orbital period | 95.6 min | 95.6 min | `T = 2π√(a³/μ)` |
| SSO 700 km orbital period | 98.8 min | 98.8 min | `T = 2π√(a³/μ)` |
| Contact per day, SSO 550 (Svalbard / Fairbanks / Wallops) | 4636 / 2500 / 1347 s | 4636 / 2500 / 1347 s | GMAT case table above, 7 day window tiled |
| Reference design energy per orbit, SSO 550 | +19.9 Wh: 27.5 Wh in over 3679 s of sun, 7.6 Wh out | +19.9 Wh | hand calculation from `SimInput` loads |
| Reference design data generated in 30 days | 1 Mbit/s × 20 % × 30 d = 64,800 MB | 64,800 MB | hand calculation |
| Data bookkeeping | generated = delivered + discarded + stored | holds every step | `tests/test_simulator.gd` |

The reference design is the one in `tests/test_wildfire_watch.gd`: 6U, 6U deployable array, 43 Wh battery, S-band, thermal camera at 20 %, Svalbard and Fairbanks, rideshare to SSO 550.

### Balance pass (Wildfire Watch)

`tools/balance.gd` flies every design that passes the launch check: each structure, solar array, battery, radio and pointing system, each camera at 10, 25, 50 and 100 % time, every set of ground stations, every launcher and orbit pair. No failures and nobody at the controls, so it measures the design alone. 12,096 designs, goal 100,000 MB sent home in 30 days.

| | Designs | Meet the goal | Cheapest that meets it |
|---|---|---|---|
| All | 12,096 | 26 % | 252 kUSD: thermal, X-band, free ISS launch, 100 % |
| UHF radio | 4,032 | 0 % | |
| S-band radio | 4,032 | 14 % | 567 kUSD: thermal, rideshare SSO 550, all three stations, 100 % |
| X-band radio | 4,032 | 63 % | 252 kUSD |
| Thermal camera | 4,032 | 16 % | 252 kUSD |
| Multispectral camera | 4,032 | 33 % | 282 kUSD: X-band, ISS launch, 25 % |
| Fire detection camera | 4,032 | 29 % | 532 kUSD: X-band, ISS launch, 25 % |
| LEO 400 (ISS launch) | 6,048 | 15 % | 252 kUSD |
| SSO 550 (rideshare) | 6,048 | 37 % | |

The reference design misses the goal at 10 % and 25 % camera time (32,342 and 80,856 MB) and meets it at 50 % (133,440 MB, downlink limited).

What the sweep says, as input for the playtest:

- **The budget never binds.** The most expensive launchable design costs 953 kUSD against a 1,000 kUSD budget, and the cheapest winner spends a quarter of it. Every cost is fictional, so this is the knob to turn if budget should matter.
- **No design is ever lost.** Safe mode always catches the battery before zero, so power costs science but never the spacecraft. Losses only come from live failures.
- **The structure changes nothing in flight.** 3U and 6U give the same results; mass stays under 12 kg either way and `max_payload_kg` is not checked.
- **SSO 700 is out of reach.** Only the dedicated launcher flies there, at 7,500 kUSD.
- **The UHF radio never wins**, which is the intended lesson: 9.6 kbit/s cannot move pictures.
- Raising the goal makes the budget bind (above about 256,000 MB the free ISS launch cannot deliver enough), but it also rules out S-band, which the current goal keeps on purpose (DESIGN.md open question 6). The goal stays at 100,000 MB.

## References

- GMAT R2025a, NASA GSC-19468-1: https://software.nasa.gov/software/GSC-19468-1
- CubeSat Design Specification Rev. 14.1 and 6U CubeSat Design Specification Rev. 1.0, Cal Poly CubeSat program
- NASA CubeSat Launch Initiative: https://www.nasa.gov/kennedy/launch-services-program/cubesat-launch-initiative/
- NASA Near Space Network: https://www.nasa.gov/directorates/somd/space-communications-navigation-program/near-space-network/
- Component and launcher pages: see the `source` field of each entry in `data/`

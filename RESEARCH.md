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

_To be filled as each `sim/` module lands: equation, inputs, constants with sources, simplifications._

- Orbit (`sim/orbit.gd`)
- Power (`sim/power.gd`)
- Link budget (`sim/link.gd`)
- Propulsion (`sim/propulsion.gd`)
- Mass and cost budgets (`sim/budget.gd`)
- Lifetime and reliability (`sim/lifetime.gd`)

## Data sources

_Component, launcher, orbit and real mission tables in `data/`, with the source of every value._

## Validation

| Check | Expected | Margin | Source |
|---|---|---|---|
| LEO 400 km orbital period | ~92 min | | GMAT |
| LEO 400 km eclipse fraction | ~35 to 40 % | | GMAT |
| Solar flux at Mars vs Earth | ~43 % | | inverse square law |
| Delta-v for a sample stage | hand calculation | | Tsiolkovsky |

## References

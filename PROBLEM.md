# Problem

## Challenge

NASA Space Apps Challenge 2026, **Space Mission Design Game** (Intermediate, Beginner/Youth, Games).
Official page: https://www.spaceappschallenge.org/2026/challenges/space-mission-design-game/

Designing a space mission means balancing mission objectives, spacecraft design, instruments, launch vehicles, budget, power, mass, communications and orbit. Students rarely get to try a whole mission from concept to operation, so these trade-offs stay abstract. The challenge asks for an interactive game where players design, manage and simulate a complete mission, make engineering decisions with limited resources, and see how each choice shapes the outcome.

## Who it is for

Students and newcomers with little or no space engineering background (Beginner/Youth), plus players who want deeper trade-offs (Intermediate). Played alone or by a team of up to four on one screen.

## How Margin answers the brief

Status: ✅ done, 🟡 in progress, ❌ not started, ⏭ out of scope for the hackathon.

### Objectives

| Brief item | Margin feature | Status |
|---|---|---|
| Define a mission objective | Briefing screen, scenario cards | 🟡 |
| Establish mission requirements | Requirements screen (CML 2) | ❌ |
| Design a spacecraft | Design screen, Spacecraft tab | ✅ |
| Select scientific instruments | Design screen, Science tab | ✅ |
| Choose launch vehicle and orbit | Design screen, Launch tab | ✅ |
| Manage budget, mass, power, comms, data, lifetime | Live margin panel on every screen | 🟡 |
| Solo or team of up to four | Lobby with four roles, local co-op | ❌ |
| See how decisions affect other parts | Margin panel reacts to every change, "why?" tooltips | 🟡 |

### Strong solution

| Brief item | Margin feature | Status |
|---|---|---|
| Clear user interface | One screen per mission phase, margin panel always visible | 🟡 |
| Mission configuration system | Data driven catalog in `data/*.json` | 🟡 |
| Resource management mechanisms | Margin rules in `sim/budget.gd` | ❌ |
| Collaboration for up to four | Roles plus Review Board, launch locked until every role says Go | ❌ |
| Simulation and evaluation | `sim/simulator.gd`, mission report | 🟡 |
| Reward good engineering, efficiency, collaboration, objectives | `sim/scoring.gd` | ❌ |

### Suggested features

| Brief item | Margin feature | Status |
|---|---|---|
| Multiple scenarios | Wildfire Watch, Crop Scout, Lunar Ice Mapper, Red Relay | ❌ |
| Random events | Solar storm, battery fade, ground station outage, launch slip, budget cut | ❌ |
| Difficulty levels | Simple and advanced component catalogs, scenario difficulty multiplier | ❌ |
| Realistic or simplified spacecraft models | Simplified models backed by CubeSat 101 numbers | 🟡 |
| Interactive spacecraft visualization | Spacecraft preview on the Design screen | ✅ |
| Real time resource dashboard | Simulation screen gauges | ✅ |
| Leaderboard | Local leaderboard | ❌ |
| End of mission report | Report screen | ✅ |
| Save, share, compare designs | JSON export/import, Trade Study screen | ❌ |
| Cooperative missions | Four role local co-op | ❌ |
| Competitive scenarios | Two teams, same scenario, scores side by side | ⏭ stretch |
| Sandbox mode | Sandbox scenario with no constraints | ❌ |
| Post mission analysis | Report explains the failure with numbers, shows the closest real NASA mission | ❌ |

## Out of scope

- Online multiplayer (local co-op only during the hackathon)
- High fidelity orbital propagation (GMAT is used offline to sanity check our simple models)
- Mobile layout

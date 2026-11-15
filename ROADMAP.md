# Roadmap

Hackathon: 14 to 15 November 2026, 48 hours. Hours count from kickoff.

## Phase 0 · Setup (0 to 3 h)

- [x] Repo and Godot project
- [x] PROBLEM, RESEARCH, ROADMAP, README skeletons
- [x] Folder layout, autoloads (`Catalog`, `GameState`, `EventBus`)
- [x] First data contracts: `MissionDesign`, `Scenario`, `DayState`
- [x] GUT test runner
- [x] Empty Linux and Windows builds exported and launched on each. (Windows is tested via Wine)

## Phase 1 · Core simulation (3 to 14 h)

- [x] Data schema: unit suffixes, `provenance` labels, `safe_power_w`; `Catalog` converts to SI at load
- [x] Orbit table for 2–3 orbits: eclipse fraction and contact windows from GMAT, assumptions in RESEARCH.md
- [x] Orbit timeline: period from `T = 2π√(a³/μ)`, eclipse and contact intervals, per-step `{sunlit, contact}`
- [x] 60 s simulation loop, duration from the scenario
- [x] Power and operating modes: Normal / Safe with enter and exit thresholds, mission loss at zero charge in Safe
- [x] Data chain: generation, storage, downlink, overflow discard; `generated = delivered + discarded + stored` tested
- [x] Launch check: mass, orbit reachability, budget
- [x] Design-time warnings: energy per orbit, data generated vs deliverable per day
- [x] `DayState` updated: operating mode, safe-mode time, data totals, mode events, one end reason
- [x] Wildfire Watch catalog: at most 3 options per category, every value labelled; cost model still open

## Phase 2 · First playable (14 to 24 h)

- [x] Briefing, design screen, launch check feedback
- [x] Prediction screen: one or more expected limiting factors
- [x] Mission run view: battery, storage, downlink over time
- [x] Report: objective result, delivered and lost data with causes, prediction vs actual
- [x] Redesign and run again
- [x] Informal playtesting by the team and friends; the issues they found were fixed (unclear mission purpose, pause panel and controls, the goal line, no way to leave a mission). No structured usability study was run. The remaining design concerns from a player's point of view are in the review notes (sandbox depth, predictable part choices), not results from user testing.

## Phase 3 · Optional features (24 to 36 h)

Only after Phase 2 works end to end.

- [x] Balance pass, validation table in RESEARCH.md
- [x] Design comparison (two runs side by side)
- [ ] Optional, after the hackathon: local role-based play at one screen
- [ ] Optional, after the hackathon: further scenarios, sandbox
- [x] 3D spacecraft preview on the design screen, built from the chosen parts
- [x] Launch pad between prediction and run: preflight GO/NO GO, final inspection, launch milestones (shown, not simulated)
- [x] 3D launch: launch site, liftoff, ascent, fairing and spacecraft separation in orbit
- [x] Live failures in flight (battery fade, solar string, radio and camera hangs) with power cycle recovery
- [x] How to play screen

## Phase 4 · Freeze (36 to 42 h)

- [x] Code freeze, bug fixes
- [x] Final Linux and Windows builds exported from main and launched (Windows via Wine); published by pushing a `v*` tag
- [x] Docs up to date

## Phase 5 · Submit (42 to 48 h)

- [ ] 30 second video, slides
- [ ] Space Apps project page: summary, NASA resources used, AI disclosure
- [ ] Submit (not in the last two hours)

## After the hackathon

- Networked multiplayer (needs session management, state sync, conflict handling)
- Random events with sourced probabilities
- Leaderboard, competitive team mode, closest real mission card

# Changelog

All notable changes to Margin are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Project website with downloads for the latest release, the gameplay video and the main menu's turning Earth.

## [0.1.0] (2026-11-15)

First playable release, built during the NASA Space Apps Challenge 2026.

### Added

- Wildfire Watch mission: design a small Earth observation satellite and send home enough pictures in 30 days. It opens with a short mission intro (why satellites help watch wildfires, the goal, what limits it, the player's role) that the player steps through at their own pace, skips or replays.
- Sandbox mode with no limits and no goals.
- Animated main menu with mission tiles, a turnable 3D Earth and a studio logo splash.
- How to play screen, including what the model leaves out and the units on screen (kUSD, W in full sun, Wh, MB, Safe mode).
- Design screen with parts, orbits, launchers and ground stations, live mass, cost, power and data margins and a 3D spacecraft preview built from the chosen parts. An optional pointing system: without one the camera faces the ground about a quarter of the time.
- Launch check that blocks launch when mass, budget, orbit or structure size does not fit, plus design time warnings that the player accepts on the launch pad.
- Prediction screen to guess what will limit the design, checked against the design flown alone, without failures or changes in flight.
- Launch pad with a preflight GO / NO GO check, a choice of failure mode (Training 1 to 3 failures, Uncertain 0 to 3, or None) with a button to draw new failures, and a 3D launch from the pad to separation and deployment in orbit.
- Real time mission operations with a mission clock, speed controls, auto pause, and in flight control of the camera on time and the radio. Each pause says what happened, what you can do and what happens if you resume as is, and marks the controls that can help. Reaching the goal early says that the mission flies on.
- Live failures in flight (battery fade, solar string loss, radio and camera hangs) with power cycle recovery.
- Escape opens a pause menu in flight (Resume, or leave the mission after a confirmation) and steps back on the other screens.
- Mission report with a title for both the spacecraft and the goal, delivered and lost data with causes, whether each limit came from the design, the failures or the changes in flight, prediction vs. actual, a no intervention baseline and a comparison with the previous flight that says whether both met the same failures.
- Simulation core with 60 s steps, Normal and Safe modes, data generation, storage and downlink.
- Orbit eclipse and contact data generated with GMAT R2025a.
- Earth rendered from NASA Blue Marble and Black Marble imagery.
- Interface sounds (Kenney, CC0) and a custom spaceship cursor.
- Satellite app icon for the window and the exports.
- GUT test suite covering the simulation and the UI flow.

[Unreleased]: https://github.com/farfromoffice/margin/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/farfromoffice/margin/releases/tag/v0.1.0

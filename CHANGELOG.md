# Changelog

All notable changes to Margin are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] (2026-11-14)

First playable release, built during the NASA Space Apps Challenge 2026.

### Added

- Wildfire Watch mission: design a small Earth observation satellite and send home enough pictures in 30 days.
- Sandbox mode with no limits and no goals.
- Animated main menu with mission tiles, a turnable 3D Earth and a studio logo splash.
- How to play screen.
- Design screen with parts, orbits, launchers and ground stations, live mass, cost, power and data margins, and a 3D spacecraft preview built from the chosen parts.
- Launch check that blocks launch when mass, orbit or budget does not fit, plus design time warnings.
- Prediction screen to guess what will limit the mission before it flies.
- Launch pad with a preflight GO / NO GO check and a 3D launch from the pad to separation and deployment in orbit.
- Real time mission operations with a mission clock, speed controls, auto pause, and in flight control of the camera on time and the radio.
- Live failures in flight (battery fade, solar string loss, radio and camera hangs) with power cycle recovery.
- Mission report with the result, delivered and lost data with causes, prediction vs. actual, a no intervention baseline and a comparison with the previous flight.
- Simulation core with 60 s steps, Normal and Safe modes, data generation, storage and downlink.
- Orbit eclipse and contact data generated with GMAT R2025a.
- Earth rendered from NASA Blue Marble and Black Marble imagery.
- Interface sounds (Kenney, CC0) and a custom spaceship cursor.
- Satellite app icon for the window and the exports.
- GUT test suite covering the simulation and the UI flow.

[Unreleased]: https://github.com/farfromoffice/margin/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/farfromoffice/margin/releases/tag/v0.1.0

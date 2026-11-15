# Changelog

All notable changes to Margin are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Wildfire Watch opens with a short mission intro on the briefing screen: why satellites help watch wildfires, the goal, what limits it and the player's role. It plays once per session and can be skipped or replayed.
- Failure modes on the launch pad: Training (1 to 3 failures, as before), Uncertain (0 to 3) or None, and a button to draw new failures. The report says whether two flights met the same failures.

### Changed

- Operations screen: the pause panel says what happened, what you can do and what happens if you resume as is, in that order. The sidebar groups the controls in cards and marks the ones that can help with the open pause; restart buttons only show when a part is hung. The radio switch no longer looks like a pressed alarm button and the report button stands out when the mission ends.
- Reaching the goal before the last day now says that the mission flies on and that more data still counts.
- The prediction is checked against the design alone, without failures or changes in flight; what those added is named apart. The report also tells limits the failures brought from limits of the design.
- Flying without a pointing system now costs pictures: the camera faces the ground about a quarter of the time. The design screen and launch pad say so.
- The report title says whether the goal was met, not only whether the spacecraft survived.
- How to play explains pointing, what the model leaves out, and the units on screen (kUSD, W in full sun, Wh, MB, Safe mode).
- Solar panels list their power "in full sun" instead of "peak", and the design screen says what kUSD means.

### Fixed

- The advice for a weaker battery or solar array said to keep the radio off between passes, which saves nothing: the radio only draws its sending power during passes. It now says to switch the radio off for some passes.

### Removed

- The placeholder `data/real_missions.json`; the closest real mission card is planned for after the hackathon.

### Fixed

- The goal line on the data chart (and the Safe mode line on the battery chart) blinked in and out in windows smaller than 1280x720. It's now drawn as a hairline that always shows.

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

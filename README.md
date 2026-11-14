# Margin

**Every gram counts.**

Margin is a space mission design game made for the NASA Space Apps Challenge 2026 ([Space Mission Design Game](https://www.spaceappschallenge.org/2026/challenges/space-mission-design-game/)). You design a small Earth-observation mission, predict what will limit it, run it and find out why.

Download for Linux and Windows: _builds coming soon_

## Playing

1. Read the mission briefing and its objective.
2. Choose an instrument, solar array, battery, radio, ground stations, orbit and launcher. The game blocks launch if the mass, orbit or budget does not fit.
3. Predict which constraints will limit the mission.
4. Check the preflight numbers on the launch pad and watch the launch milestones. The ascent is shown, not simulated.
5. Fly the mission: change the camera on-time and the radio while it runs. Hardware, orbit and launcher are locked after launch.
6. Read the report, change the design, try again.

## Development

Requires Godot 4.7 (GDScript, Compatibility renderer).

```sh
godot -e project.godot  # open the editor
tools/test.sh           # run the tests (GUT, config in .gutconfig.json); GODOT=/path/to/godot to pick the binary
```

Orbit eclipse and contact data in `data/orbits.json` come from GMAT R2025a. After changing an orbit or a ground station, regenerate them (Python 3, no extra packages):

```sh
python3 tools/gmat/build_orbits.py /path/to/GMAT/R2025a/bin
```

Code layout: `sim/` is pure simulation logic (see DESIGN.md), `ui/` holds the screens (`ui/screens/`), widgets, icons and fonts, `scenes/app.tscn` is the entry point and swaps screens on `EventBus.screen_requested`.

Project docs:

- [PROBLEM.md](PROBLEM.md): the challenge and how each item maps to a feature
- [RESEARCH.md](RESEARCH.md): models, data sources, validation
- [ROADMAP.md](ROADMAP.md): plan and progress
- [data/README.md](data/README.md): data schema, units and provenance rules

## Credits

Fonts: [Orbitron](https://github.com/theleagueof/orbitron) and [Exo 2](https://github.com/googlefonts/Exo-2.0), SIL Open Font License 1.1, licenses in `ui/fonts/`. Icons, the Earth and sky shaders and the 3D spacecraft are made for this project.

## Team

farfromoffice

## Disclaimer

Margin is an independent team project for the NASA Space Apps Challenge. It is not a NASA product and is not endorsed by NASA.

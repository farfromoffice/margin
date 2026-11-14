# Margin

**Every gram counts.**

Margin is a space mission design game made for the NASA Space Apps Challenge 2026 ([Space Mission Design Game](https://www.spaceappschallenge.org/2026/challenges/space-mission-design-game/)). You design a small Earth-observation mission, predict what will limit it, run it and find out why.

Download for Linux and Windows: _builds coming soon_

## Playing

1. Read the mission briefing and its objective.
2. Choose an instrument, solar array, battery, radio, ground stations, orbit and launcher. The game blocks launch if the mass, orbit or budget does not fit.
3. Predict which constraints will limit the mission.
4. Run the mission and watch power, storage and downlink.
5. Read the report, change the design, try again.

## Development

Requires Godot 4.7 (GDScript, Compatibility renderer).

```sh
godot -e project.godot                       # open the editor
godot --headless -s addons/gut/gut_cmdln.gd  # run the tests (GUT, config in .gutconfig.json)
```

On a fresh clone run `godot --headless --editor --quit` once first so Godot imports the project and registers class names.

Orbit eclipse and contact data in `data/orbits.json` come from GMAT R2025a. After changing an orbit or a ground station, regenerate them (Python 3, no extra packages):

```sh
python3 tools/gmat/build_orbits.py /path/to/GMAT/R2025a/bin
```

Project docs:

- [PROBLEM.md](PROBLEM.md): the challenge and how each item maps to a feature
- [RESEARCH.md](RESEARCH.md): models, data sources, validation
- [ROADMAP.md](ROADMAP.md): plan and progress
- [data/README.md](data/README.md): data schema, units and provenance rules

## Team

farfromoffice

## Disclaimer

Margin is an independent team project for the NASA Space Apps Challenge. It is not a NASA product and is not endorsed by NASA.

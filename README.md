# Margin

**Every gram counts.**

Margin is a space mission design game made for the NASA Space Apps Challenge 2026 ([Space Mission Design Game](https://www.spaceappschallenge.org/2026/challenges/space-mission-design-game/)). Alone or with up to three friends, you take a mission from an idea to launch and operations. Every choice eats into a margin: mass, power, budget, data, link. Let one go negative and the mission pays for it in orbit.

Play in the browser: _link coming soon_

## Playing

1. Pick a scenario and read the briefing.
2. Set your requirements.
3. Design the mission across four tabs: Launch, Spacecraft, Ground, Science.
4. Every role signs off at the Review Board.
5. Launch, watch the mission run, read the report, try again.

## Development

Requires Godot 4.7 (GDScript, Compatibility renderer).

```sh
godot -e project.godot                       # open the editor
godot --headless -s addons/gut/gut_cmdln.gd  # run the tests (GUT, config in .gutconfig.json)
```

On a fresh clone run `godot --headless --editor --quit` once first so Godot imports the project and registers class names.

Project docs:

- [PROBLEM.md](PROBLEM.md): the challenge and how each item maps to a feature
- [RESEARCH.md](RESEARCH.md): models, data sources, validation
- [ROADMAP.md](ROADMAP.md): plan and progress

## Team

farfromoffice

## Disclaimer

Margin is an independent team project for the NASA Space Apps Challenge. It is not a NASA product and is not endorsed by NASA.

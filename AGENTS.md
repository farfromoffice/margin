# AGENTS.md

Notes for AI coding agents working on Margin. Humans should read CONTRIBUTING.md first, the rules are the same.

## Project

Margin is a space mission design game for the NASA Space Apps Challenge 2026, built with Godot 4.7 in GDScript on the Compatibility renderer. The player designs a small satellite, predicts what will limit it, launches and flies it, then reads a report.

## Commands

```sh
tools/test.sh                                   # GUT suite, headless; GODOT=/path/to/godot to pick the binary
godot --headless --import                       # rebuild the class_name cache on a fresh checkout
godot -e project.godot                          # editor
python3 tools/gmat/build_orbits.py <GMAT bin>   # regenerate data/orbits.json after orbit or station changes
```

Run `tools/test.sh` before saying a change is done. All tests must pass.

## Layout

- `sim/`: pure simulation logic, `RefCounted` only, no scene tree, SI units. Contracts in DESIGN.md.
- `autoload/`: `Catalog` (loads `data/`), `GameState`, `EventBus`, `Sfx`.
- `ui/screens/`: one script per screen, swapped by `ui/app.gd` on `EventBus.screen_requested`.
- `ui/launch/`, `ui/spacecraft/`, `ui/earth/`: 3D launch site, spacecraft model, Earth.
- `data/`: JSON game data with provenance rules in data/README.md.
- `tests/`: GUT tests, one file per area.
- `addons/gut/`: vendored, do not edit.
- `docs/`: README images, ignored by Godot through `.gdignore`.

## Rules

- Match the existing style: static types, tabs, short doc comments with `##`.
- Keep `sim/` free of nodes and scene access so it stays testable headless.
- Screens talk through `EventBus` signals, not through references to each other.
- Every numeric data entry needs `source` and `provenance`. Never invent sourced values; mark teaching values as `fictional`.
- Keep changes small and focused. No drive by refactors or formatting changes.
- Update DESIGN.md, RESEARCH.md, data/README.md or README.md when behavior they describe changes, and add a line under Unreleased in CHANGELOG.md for player visible changes.
- Commits: single line Conventional Commits, lowercase, no scope, e.g. `fix: clear the pause banner on resume`. No attribution trailers.
- UI changes can not be fully checked headless. Say so if the game was not run in a window.

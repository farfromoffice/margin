# Contributing to Margin

Thanks for helping. Margin is a small Godot game, so the workflow is light.

## Setup

1. Install [Godot 4.7](https://godotengine.org/download) (standard build, not .NET).
2. Clone the repo and turn on the shared git settings (commit template, rebase on pull):

   ```sh
   git config --local include.path ../.gitconfig
   ```

3. Open the project with `godot -e project.godot` and run the tests with `tools/test.sh`. Set `GODOT=/path/to/godot` if the binary is not on your PATH.

## Making a change

1. Open an issue first for anything bigger than a small fix, so we can agree on the approach.
2. Branch from main with a `type/short-name` branch, for example `fix/radio-restart` or `feat/new-scenario`.
3. Keep each pull request to one purpose. No unrelated formatting changes.
4. Run `tools/test.sh` and play the affected screens before opening the pull request. CI runs the same tests.
5. Fill in the pull request template. A maintainer from CODEOWNERS reviews it.

## Code

- GDScript with static types, tabs for indentation, names and layout as in the existing code. `.editorconfig` covers the basics.
- `sim/` stays pure logic: `RefCounted` classes, no scene tree access, SI units inside. DESIGN.md holds the contracts.
- Screens live in `ui/screens/` and talk to each other through `EventBus`, not through direct references.
- Add or update GUT tests in `tests/` for simulation changes. UI changes should keep `tests/test_ui_flow.gd` passing.
- Leave `addons/gut/` as upstream ships it.

## Data

Game data lives in `data/*.json`. Every numeric entry needs a `source` and a `provenance` label, see [data/README.md](data/README.md). After changing an orbit or a ground station, regenerate the GMAT data as described in the README.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/) on a single line, lowercase, without a scope:

```text
feat: add a second scenario
fix: keep end of step events on their own day
docs: explain the safe mode thresholds
```

## Docs

Update README.md, DESIGN.md, RESEARCH.md or data/README.md when behavior changes, and add a line under Unreleased in CHANGELOG.md for anything a player would notice.

## Conduct

Everyone taking part follows the [Code of Conduct](CODE_OF_CONDUCT.md). Security problems go through [SECURITY.md](SECURITY.md), not public issues.

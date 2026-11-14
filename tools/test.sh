#!/bin/sh
# Runs the GUT suite. Imports first: a fresh checkout has no class_name cache
# in .godot/ and without it every test script fails to parse.
# GODOT overrides the binary, e.g. GODOT=~/Godot/Godot_v4.7.2-stable_linux.x86_64
set -e
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --import >/dev/null 2>&1
exec "$GODOT" --headless -s addons/gut/gut_cmdln.gd "$@"

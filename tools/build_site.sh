#!/usr/bin/env bash
# Assemble the website into one folder: site/ plus the screenshots, fonts and
# Earth maps the game already ships, so nothing is kept twice in the repo.
# Usage: tools/build_site.sh [out_dir]   (default: build/site)
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:-$root/build/site}"

rm -rf "$out"
mkdir -p "$out/img" "$out/fonts"
cp -r "$root/site/." "$out/"
rm -f "$out/.gdignore"

cp "$root"/docs/screenshots/*.jpg "$out/img/"
cp "$root/ui/earth/blue_marble.jpg" "$root/ui/earth/black_marble.jpg" "$root/ui/earth/wildfire.jpg" "$out/img/"
cp "$root/ui/brand/app_icon.svg" "$out/img/"
# the game tints the white icon at draw time, the site draws it as is
cp "$root/ui/icons/satellite.svg" "$out/img/"
cp "$root"/ui/fonts/*.ttf "$root"/ui/fonts/*-OFL.txt "$out/fonts/"
# GitHub Pages runs Jekyll otherwise, which we don't need
touch "$out/.nojekyll"

echo "site built in $out"

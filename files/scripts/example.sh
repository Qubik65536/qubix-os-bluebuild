#!/usr/bin/env bash
#
# Template placeholder — NOT currently used by this image.
#
# Scripts in files/scripts/ run at BUILD time, inside CI, and only if recipes/recipe.yml
# invokes them through a `script` module. Nothing here references this file, so it never
# runs. Adding a script is half the change; wiring it into the recipe is the other half.
#
# See: docs/architecture.md ("Extension points not currently used")
#      .agent/context/scripts.md
#      Task MNT-002 in .agent/plan.md decides whether this file stays.

# Fail the build on any error, unset variable, or failed pipe stage. Without this a
# broken step would be silently baked into the published image.
# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

# ── Build steps go here ───────────────────────────────────────────────────────
# Your code goes here.
echo 'This is an example shell script'
echo 'Scripts here will run during build if specified in recipe.yml'

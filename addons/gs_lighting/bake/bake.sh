#!/usr/bin/env bash
#
# Bake every bake scene in one directory of a project, unattended.
#
#   addons/gs_lighting/bake/bake.sh <project dir> res://<dir with bake scenes>
#
# The scenes come from the game (GSLightBake.prepare puts a LightmapGI and the output path in
# each); this opens the project in the editor under a virtual display with Forward+ on Vulkan
# (the Compatibility renderer cannot bake) and lets GameSpice Lighting's editor plugin bake each one
# and write the shipped file (editor/gs_light_bake_runner.gd). Prints the runner's GS_BAKE
# lines; exits non-zero if any scene did not bake.
#
# Mesa's software Vulkan (lavapipe) is enough in principle and takes many minutes for one map;
# a real card takes seconds. On the family's VMs run it through `heavy`, or on the GPU box.
#
# The project must enable gs-lighting's editor plugin in project.godot (it is inert without the
# flag). Enabling it for one run through override.cfg does not work: the editor reads
# [editor_plugins] from project.godot alone, and the runner never starts.
set -uo pipefail

PROJECT="${1:?usage: bake.sh <project dir> res://<scene dir>}"
SCENES="${2:?usage: bake.sh <project dir> res://<scene dir>}"
GODOT="${GODOT:-godot}"
PROJECT="$(cd "$PROJECT" && pwd -P)"
LOG="$PROJECT/.godot/gs-light-bake.log"

[ -f "$PROJECT/project.godot" ] || { echo "no project.godot in $PROJECT" >&2; exit 2; }
grep -q 'res://addons/gs_lighting/plugin.cfg' "$PROJECT/project.godot" \
    || { echo "enable gs-lighting's editor plugin in $PROJECT/project.godot first" >&2; exit 2; }
command -v xvfb-run >/dev/null || { echo "needs xvfb-run (Debian: xvfb)" >&2; exit 2; }

mkdir -p "$PROJECT/.godot"
xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --editor --path "$PROJECT" \
    --rendering-method forward_plus --rendering-driver vulkan \
    -- "--gs-bake-lightmaps=$SCENES" > "$LOG" 2>&1
status=$?
grep '^GS_BAKE' "$LOG"
grep -q '^GS_BAKE end' "$LOG" || { echo "the editor stopped before the end (status $status); log: $LOG" >&2; exit 1; }
exit $status

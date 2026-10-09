#!/usr/bin/env bash
# V37+ Android build pipeline.
#
# The v1.3.0 tree ships its non-texture assets in GDRE-recovered form
# (X.ext.remap -> compiled/X.<artefact>), so the build MUST run in this
# order:
#   1. --import        editor imports real textures; it also rewrites a
#                      few recovered .import files to .godot/imported/
#                      paths whose artifacts do not exist yet
#   2. fix_imports.py  copies each compiled artifact to the exact path
#                      the rewritten .import expects
#   3. --export-release packs everything: for recovered assets the
#                      [remap] path (compiled/ or .godot/imported/) and
#                      the .import file itself go into the PCK, so the
#                      runtime loads X.ogg/.glb/.svg transparently
set -euo pipefail
GODOT="${GODOT:-/home/z/my-project/pak/Godot_v4.7.2-stable_linux.x86_64}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import
python3 tools/fix_imports.py
mkdir -p build
"$GODOT" --headless --path . --export-release "Android" build/ftn-v3.0.1-universal.apk
echo "OK: build/ftn-v3.0.1-universal.apk"

#!/usr/bin/env bash
# Builds the browser version into build/artifact/ for publishing as a claude.ai Artifact.
# Needs Godot 4.3 with the web export templates installed.
# Usage: GODOT=/path/to/godot4 tools/build_web.sh
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
rm -rf build/web build/artifact
mkdir -p build/web build/artifact
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
# Artifact files are capped at 15MB and must be web file types:
# split the 35MB engine into .wasm parts, embed the .pck as base64 JS.
split -b 12000000 -d -a 1 build/web/index.wasm build/artifact/index.part
for f in build/artifact/index.part?; do mv "$f" "$f.wasm"; done
python3 - <<'PY'
import base64
d = open("build/web/index.pck", "rb").read()
open("build/artifact/index.pck.js", "w").write(
    "// Game data (Godot .pck), base64. Artifacts only serve web file types.\n"
    "window.GAME_PCK_B64 = \"" + base64.b64encode(d).decode() + "\";\n")
PY
cp build/web/index.js build/web/index.audio.worklet.js build/artifact/
# The page hard-codes the sizes for progress and integrity checks; keep them in sync.
WASM_SIZE=$(stat -c %s build/web/index.wasm)
PCK_SIZE=$(stat -c %s build/web/index.pck)
sed -e "s/const WASM_SIZE = [0-9]*;/const WASM_SIZE = $WASM_SIZE;/" \
	-e "s/const PCK_SIZE = [0-9]*;/const PCK_SIZE = $PCK_SIZE;/" \
	web/pixel-defense.html > build/artifact/pixel-defense.html
ls -la build/artifact

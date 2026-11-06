#!/bin/sh
# Syntax-checks every addon file and runs the test suite in Lua 5.1, the
# version WoW embeds. Needs Docker or Colima (containerd runtime).
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
IMAGE=nickblah/lua:5.1

if docker info >/dev/null 2>&1; then
	RUN="docker run"
elif command -v colima >/dev/null 2>&1; then
	RUN="colima nerdctl -- run"
else
	echo "Need Docker or Colima to run Lua 5.1." >&2
	exit 1
fi

$RUN --rm -v "$ROOT:/src:ro" -w /src "$IMAGE" sh -c '
	set -e
	find ForeverGraphicsTweaks tests -name "*.lua" | sort | while read -r f; do
		luac -p "$f" || exit 1
	done
	echo "luac -p: all files parse"
	lua tests/run.lua /src
'

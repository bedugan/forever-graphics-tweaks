#!/bin/sh
# Syntax-checks every addon file, runs the test suite in Lua 5.1 (the
# version WoW embeds), and checks docs/SETTINGS.md matches the definitions.
# Needs Docker or Colima (containerd runtime).
# scripts/test.sh --write-docs regenerates docs/SETTINGS.md instead.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
IMAGE=nickblah/lua:5.1

MODE=test
if [ "${1:-}" = "--write-docs" ]; then
	MODE=docs
fi

if docker info >/dev/null 2>&1; then
	RUN="docker run"
elif command -v colima >/dev/null 2>&1; then
	RUN="colima nerdctl -- run"
else
	echo "Need Docker or Colima to run Lua 5.1." >&2
	exit 1
fi

if [ "$MODE" = docs ]; then
	$RUN --rm -v "$ROOT:/src:ro" -w /src "$IMAGE" lua scripts/settings_doc.lua /src >"$ROOT/docs/SETTINGS.md"
	echo "Wrote docs/SETTINGS.md"
	exit 0
fi

$RUN --rm -v "$ROOT:/src:ro" -w /src "$IMAGE" sh -c '
	set -e
	find GraphicsSettingsManager tests -name "*.lua" | sort | while read -r f; do
		luac -p "$f" || exit 1
	done
	echo "luac -p: all files parse"
	lua tests/run.lua /src
	lua scripts/settings_doc.lua /src | diff -u docs/SETTINGS.md - >/dev/null \
		|| { echo "docs/SETTINGS.md is stale. Run scripts/test.sh --write-docs"; exit 1; }
	echo "docs/SETTINGS.md matches the definitions"
'

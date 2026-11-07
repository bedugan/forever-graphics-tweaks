#!/bin/sh
# Turns /gsmcap screenshots into the comparison images GSM ships.
#
#   scripts/import_captures.sh [--wow DIR | --log FILE --screens DIR] [--run N] [--only cvar,cvar]
#   scripts/import_captures.sh --manifest-only   rebuild Media/Manifest.lua from assets/screenshots.json
#   scripts/import_captures.sh --test            run the import's own tests
#
# --wow defaults to the macOS Forever install. The script only reads the WoW
# folders: it copies the capture log and that run's screenshots into
# .capture/in (ignored by git), and the container sees only this repo.
# Needs Docker or Colima.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
IMAGE=gsm-capture-tools:1
WOW="/Applications/World of Warcraft/_forever_"
LOG=""
SCREENS=""
MODE=import
RUNARG=""
ONLY=""

while [ $# -gt 0 ]; do
	case "$1" in
	--wow) WOW=$2; shift 2 ;;
	--log) LOG=$2; shift 2 ;;
	--screens) SCREENS=$2; shift 2 ;;
	--run) RUNARG="--run $2"; shift 2 ;;
	--only) ONLY="--only $2"; shift 2 ;;
	--manifest-only) MODE=manifest; shift ;;
	--test) MODE=test; shift ;;
	*) echo "Unknown option $1. See the top of $0." >&2; exit 2 ;;
	esac
done

if docker info >/dev/null 2>&1; then
	RUN="docker run"
	BUILD="docker build"
elif command -v colima >/dev/null 2>&1; then
	RUN="colima nerdctl -- run"
	BUILD="colima nerdctl -- build"
else
	echo "Need Docker or Colima." >&2
	exit 1
fi

if ! $RUN --rm "$IMAGE" true >/dev/null 2>&1; then
	echo "Building $IMAGE (one time)."
	$BUILD -t "$IMAGE" -f "$ROOT/scripts/capture/Containerfile" "$ROOT/scripts/capture" >/dev/null
fi

py() {
	$RUN --rm -v "$ROOT:/src" -w /src "$IMAGE" python -I scripts/capture/gsm_import.py "$@"
}

case "$MODE" in
test)
	$RUN --rm -v "$ROOT:/src:ro" -w /src/scripts/capture "$IMAGE" python -m unittest -q test_gsm_import
	exit 0
	;;
manifest)
	py manifest --repo /src
	exit 0
	;;
esac

if [ -z "$LOG" ]; then
	set -- "$WOW"/WTF/Account/*/SavedVariables/GraphicsSettingsManager_Capture.lua
	if [ ! -f "$1" ]; then
		echo "No capture log under $WOW/WTF. Capture with /gsmcap, then /reload, or pass --log." >&2
		exit 1
	fi
	if [ $# -gt 1 ]; then
		echo "More than one account has a capture log. Pass --log with the one to use." >&2
		exit 1
	fi
	LOG=$1
fi
SCREENS=${SCREENS:-"$WOW/Screenshots"}

IN="$ROOT/.capture/in"
rm -rf "$IN"
mkdir -p "$IN/screens"
cp "$LOG" "$IN/capture.lua"
# Copy only screenshots from the days the run took them.
for day in $(py dates --log /src/.capture/in/capture.lua $RUNARG 2>/dev/null | grep -E '^[0-9]{6}$' || true); do
	for file in "$SCREENS"/WoWScrnShot_"$day"_*; do
		[ -f "$file" ] && cp "$file" "$IN/screens/"
	done
done
echo "Staged $(ls "$IN/screens" | wc -l | tr -d ' ') screenshots."
# shellcheck disable=SC2086
py import --log /src/.capture/in/capture.lua --screens /src/.capture/in/screens --repo /src $RUNARG $ONLY

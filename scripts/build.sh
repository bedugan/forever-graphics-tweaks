#!/bin/sh
# Builds dist/GraphicsSettingsManager-<version>.zip with the addon folder at
# the top level, ready to unzip into Interface/AddOns.
# Pass --ref <commit-or-tag> to package committed files without local edits.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ADDON=GraphicsSettingsManager

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
if [ $# -eq 0 ]; then
	cp -R "$ROOT/$ADDON" "$STAGE/$ADDON"
	cp "$ROOT/LICENSE" "$STAGE/LICENSE"
elif [ $# -eq 2 ] && [ "$1" = "--ref" ]; then
	REF=$(git -C "$ROOT" rev-parse --verify "$2^{commit}")
	git -C "$ROOT" archive --format=tar --output="$STAGE/source.tar" "$REF" -- "$ADDON" LICENSE
	tar -xf "$STAGE/source.tar" -C "$STAGE"
	echo "Source commit: $REF"
else
	echo "Usage: scripts/build.sh [--ref <commit-or-tag>]" >&2
	exit 2
fi

VERSION=$(sed -n 's/^## Version: *//p' "$STAGE/$ADDON/$ADDON.toc" | tr -d '\r')
CODE_VERSION=$(sed -n 's/^ns.version = "\(.*\)"/\1/p' "$STAGE/$ADDON/Core/Namespace.lua")
if [ "$VERSION" != "$CODE_VERSION" ]; then
	echo "TOC version $VERSION does not match Namespace.lua version $CODE_VERSION" >&2
	exit 1
fi

OUT="$ROOT/dist/$ADDON-$VERSION.zip"
mkdir -p "$ROOT/dist"
rm -f "$OUT"
cp "$STAGE/LICENSE" "$STAGE/$ADDON/LICENSE.txt"
cd "$STAGE"
zip -qr -X "$OUT" "$ADDON" -x '*.DS_Store' '*/._*' '*/__MACOSX/*'
echo "Built dist/$ADDON-$VERSION.zip"
unzip -l "$OUT" | tail -1

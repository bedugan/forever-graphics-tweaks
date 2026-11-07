#!/bin/sh
# Builds dist/ForeverGraphicsTweaks-<version>.zip with the addon folder at
# the top level, ready to unzip into Interface/AddOns.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ADDON=ForeverGraphicsTweaks

VERSION=$(sed -n 's/^## Version: *//p' "$ROOT/$ADDON/$ADDON.toc" | tr -d '\r')
CODE_VERSION=$(sed -n 's/^ns.version = "\(.*\)"/\1/p' "$ROOT/$ADDON/Core/Namespace.lua")
if [ "$VERSION" != "$CODE_VERSION" ]; then
	echo "TOC version $VERSION does not match Namespace.lua version $CODE_VERSION" >&2
	exit 1
fi

OUT="$ROOT/dist/$ADDON-$VERSION.zip"
mkdir -p "$ROOT/dist"
rm -f "$OUT"
# Stage a copy so the license ships inside the addon folder.
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R "$ROOT/$ADDON" "$STAGE/$ADDON"
cp "$ROOT/LICENSE" "$STAGE/$ADDON/LICENSE.txt"
cd "$STAGE"
zip -qr -X "$OUT" "$ADDON" -x '*.DS_Store'
echo "Built dist/$ADDON-$VERSION.zip"
unzip -l "$OUT" | tail -1

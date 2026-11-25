#!/bin/bash
# Build DisplayPro/Resources/DisplayPro.icns from DisplayPro/DisplayPro.iconset.
#
# The .iconset folder is the single source of truth for the app icon. Its PNGs
# are named by pixel size (icon_512x512.png is 512px), which is not the naming
# `iconutil` expects — it wants logical-point names with @2x variants, and
# silently ignores anything else (icon_64x64.png was being dropped entirely).
#
# So we stage a canonical iconset in a temp dir, mapping each source PNG onto
# every slot its pixel size can fill, then hand that to iconutil. Drop a
# 1024px PNG into the source folder and the 512x512@2x slot fills itself.

set -euo pipefail

cd "$(dirname "$0")"

SRC_ICONSET="DisplayPro/DisplayPro.iconset"
OUT_ICNS="DisplayPro/Resources/DisplayPro.icns"

[ -d "$SRC_ICONSET" ] || { echo "error: $SRC_ICONSET not found" >&2; exit 1; }

STAGE="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$STAGE"
trap 'rm -rf "$(dirname "$STAGE")"' EXIT

# pixel size -> iconset slots it can serve (1x at that size, 2x at half)
slots_for() {
    case "$1" in
        16)   echo "icon_16x16.png" ;;
        32)   echo "icon_16x16@2x.png icon_32x32.png" ;;
        64)   echo "icon_32x32@2x.png" ;;
        128)  echo "icon_128x128.png" ;;
        256)  echo "icon_128x128@2x.png icon_256x256.png" ;;
        512)  echo "icon_256x256@2x.png icon_512x512.png" ;;
        1024) echo "icon_512x512@2x.png" ;;
        *)    echo "" ;;
    esac
}

found=0
for png in "$SRC_ICONSET"/*.png; do
    [ -e "$png" ] || continue

    width=$(sips -g pixelWidth "$png" | awk '/pixelWidth:/ {print $2}')
    height=$(sips -g pixelHeight "$png" | awk '/pixelHeight:/ {print $2}')

    if [ "$width" != "$height" ]; then
        echo "warning: skipping $(basename "$png") — not square (${width}x${height})" >&2
        continue
    fi

    slots=$(slots_for "$width")
    if [ -z "$slots" ]; then
        echo "warning: skipping $(basename "$png") — ${width}px is not an icon size" >&2
        continue
    fi

    for slot in $slots; do
        cp "$png" "$STAGE/$slot"
    done
    found=$((found + 1))
done

[ "$found" -gt 0 ] || { echo "error: no usable PNGs in $SRC_ICONSET" >&2; exit 1; }

mkdir -p "$(dirname "$OUT_ICNS")"
iconutil --convert icns --output "$OUT_ICNS" "$STAGE"

echo "Built ${OUT_ICNS} from ${found} source image(s) in ${SRC_ICONSET}"

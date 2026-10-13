#!/bin/sh
# cuts the edited pieces out of the repository files (read only) for fix.cpp
R=/e/Projects/tandemcommander/src/plugins
D=$(dirname "$0")
# class CZStringBuffer ... to the end of the file
awk '/^class CZStringBuffer/ {on=1} on {print}' "$R/diskmap/DiskMap/Utils.CZString.h" | tr -d '\r' > "$D/zbuf_excerpt.h"
# inline BOOL ThumbsMakeFullName ... to its closing brace
awk '/^inline BOOL ThumbsMakeFullName/ {on=1} on {print} on && /^}/ {exit}' "$R/pictview/thumbs.cpp" | tr -d '\r' > "$D/thumbs_excerpt.h"
wc -l "$D/zbuf_excerpt.h" "$D/thumbs_excerpt.h"

#!/usr/bin/env bash
# Package the shippable mod as a release zip.
#
# Usage: package.sh [version]
# Output: dist/Domainwright-<version>.zip containing the contents of mod/.
set -euo pipefail

VERSION="${1:-dev}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/mod"
OUT_DIR="$ROOT/dist"
OUT="$OUT_DIR/Domainwright-${VERSION}.zip"

if [ ! -f "$SRC/descriptor.mod" ]; then
    echo "error: $SRC/descriptor.mod not found" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
rm -f "$OUT"

if command -v zip >/dev/null 2>&1; then
    (cd "$SRC" && zip -r -q "$OUT" . -x '*.DS_Store' -x '__MACOSX*')
else
    # Fallback for Windows runners without zip.exe.
    python3 - "$SRC" "$OUT" <<'PY'
import sys, zipfile
from pathlib import Path

src, out = Path(sys.argv[1]), Path(sys.argv[2])
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(src.rglob("*")):
        if path.is_file() and ".DS_Store" not in path.name:
            archive.write(path, path.relative_to(src).as_posix())
PY
fi

echo "packaged $OUT"

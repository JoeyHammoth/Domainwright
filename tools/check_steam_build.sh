#!/usr/bin/env bash
# Probe Steam's public build id for a game, so CI can notice a patch.
#
# Usage: check_steam_build.sh [appid] [branch]
# Prints: buildid=<id>
#
# Requires steamcmd on PATH. Logs in anonymously, which is enough for app info.
set -euo pipefail

APPID="${1:-1158310}"
BRANCH="${2:-public}"

if ! command -v steamcmd >/dev/null 2>&1; then
    echo "error: steamcmd not found on PATH" >&2
    exit 1
fi

TMP_LOG="$(mktemp)"
trap 'rm -f "$TMP_LOG"' EXIT

# app_info_update 1 forces a refresh of the cached app info.
steamcmd +login anonymous +app_info_update 1 +app_info_print "$APPID" +quit >"$TMP_LOG" 2>&1 || true

BUILDID="$(awk -v want="\"$BRANCH\"" '
    $0 ~ want { found = 1 }
    found && /"buildid"/ {
        if (match($0, /"[0-9]+"/)) {
            print substr($0, RSTART + 1, RLENGTH - 2)
            exit
        }
    }
' "$TMP_LOG")"

if [ -z "$BUILDID" ]; then
    echo "error: could not find a build id for app ${APPID} branch ${BRANCH}" >&2
    echo "----- steamcmd output (tail) -----" >&2
    tail -n 40 "$TMP_LOG" >&2
    exit 1
fi

echo "buildid=${BUILDID}"

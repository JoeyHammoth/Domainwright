#!/usr/bin/env bash
# Walk the runtime checklist and record the result as a file under tests/runtime/runs/.
#
# Usage:
#   tools/run_checklist.sh [--log <error.log>] [--build <id>] [--out <file>] [--post]
#
# Answers, one per row: p = pass, f = fail, s = skip. Anything after the letter is kept
# as a note, so "f tooltip shows a raw key" records a failure with that note. q stops.
#
# --log greps the game's error.log for dlc_ lines and appends them to the report.
# --post comments the finished report on issue #6 and needs an authenticated gh.

set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
checklist="$root/tests/runtime/checklist.md"
log=""
build=""
out=""
post=0

# Rows the milestone decision reads directly; see "Verdict rules" in the checklist.
fatal_rows="R1 R3 R4 R7"
fixable_rows="R5 R6 R10 R12 R13 R14 R15 R17"

while [ "$#" -gt 0 ]; do
	case "$1" in
		--log) log="${2-}"; shift 2 ;;
		--build) build="${2-}"; shift 2 ;;
		--out) out="${2-}"; shift 2 ;;
		--post) post=1; shift ;;
		-h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
		*) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
	esac
done

if [ ! -f "$checklist" ]; then
	printf 'error: %s not found\n' "$checklist" >&2
	exit 2
fi

ids=()
titles=()
crits=()
while IFS=$'\t' read -r id title crit; do
	ids+=("$id")
	titles+=("$title")
	crits+=("$crit")
done < <(awk -F'|' '
	/^\|[[:space:]]*R[0-9]+[[:space:]]*\|/ {
		for (i = 2; i <= 4; i++) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i) }
		printf "%s\t%s\t%s\n", $2, $3, $4
	}' "$checklist")

if [ "${#ids[@]}" -eq 0 ]; then
	printf 'error: no checklist rows found in %s\n' "$checklist" >&2
	exit 1
fi

results="$(mktemp)"
trap 'rm -f "$results"' EXIT

row_status() { awk -F'\t' -v id="$1" '$1 == id { print $2; exit }' "$results"; }
row_note() { awk -F'\t' -v id="$1" '$1 == id { print $3; exit }' "$results"; }
row_title() {
	local i
	for i in "${!ids[@]}"; do
		[ "${ids[$i]}" = "$1" ] && { printf '%s' "${titles[$i]}"; return; }
	done
}
row_crit() {
	local i
	for i in "${!ids[@]}"; do
		[ "${ids[$i]}" = "$1" ] && { printf '%s' "${crits[$i]}"; return; }
	done
}

# Only console syntax that already exists in the checklist is printed here; nothing is
# invented, because a wrong console line costs more time than it saves.
hint() {
	case "$1" in
		R1) printf '       console: effect = { dlc_set_delta_effect = { VALUE = 8 } }  then  VALUE = -3\n' ;;
		R3) printf '       console: effect = { dlc_reset_effect = yes }\n' ;;
		R7) printf '       console: effect = { dlc_set_delta_effect = { VALUE = 999 } }  then  VALUE = -999\n' ;;
		R10) printf '       copy the save before removing anything from the load order\n' ;;
		R15) printf '       use the menu button; a scripted loop would skip the code path under test\n' ;;
		*) : ;;
	esac
}

printf 'Domainwright runtime checklist: %d rows.\n' "${#ids[@]}"
printf 'Answer p, f or s; text after the letter becomes a note. q quits.\n'

index=0
while [ "$index" -lt "${#ids[@]}" ]; do
	id="${ids[$index]}"
	printf '\n[%d/%d] %s  %s\n' "$((index + 1))" "${#ids[@]}" "$id" "${titles[$index]}"
	printf '       pass: %s\n' "${crits[$index]}"
	hint "$id"
	printf '       > '

	answer=""
	if ! IFS= read -r answer; then
		printf '\n(no more input; recording the remaining rows as skipped)\n'
		break
	fi

	status="${answer%% *}"
	note="${answer#"$status"}"
	note="${note# }"

	case "$status" in
		p|P) status=p ;;
		f|F) status=f ;;
		s|S|"") status=s ;;
		q|Q) printf '       stopped at %s\n' "$id"; break ;;
		*) printf '       unrecognised answer; recording as skipped\n'; status=s ;;
	esac

	printf '%s\t%s\t%s\n' "$id" "$status" "$note" >> "$results"
	index=$((index + 1))
done

for id in "${ids[@]}"; do
	if [ -z "$(row_status "$id")" ]; then
		printf '%s\ts\tnot run\n' "$id" >> "$results"
	fi
done

passed=0
failed=0
skipped=0
for id in "${ids[@]}"; do
	case "$(row_status "$id")" in
		p) passed=$((passed + 1)) ;;
		f) failed=$((failed + 1)) ;;
		*) skipped=$((skipped + 1)) ;;
	esac
done

fatal_failed=""
fatal_skipped=""
for id in $fatal_rows; do
	case "$(row_status "$id")" in
		f) fatal_failed="$fatal_failed $id" ;;
		p) : ;;
		*) fatal_skipped="$fatal_skipped $id" ;;
	esac
done

fixable_failed=""
for id in $fixable_rows; do
	[ "$(row_status "$id")" = f ] && fixable_failed="$fixable_failed $id"
done

if [ -n "$fatal_failed" ]; then
	verdict="NO-GO"
	reason="fatal rows failed:$fatal_failed"
elif [ -n "$fatal_skipped" ]; then
	verdict="INCOMPLETE"
	reason="fatal rows not run:$fatal_skipped"
else
	verdict="GO"
	reason="every fatal row passed"
	[ -n "$fixable_failed" ] && reason="$reason; follow-up needed for:$fixable_failed"
fi

if [ -z "$build" ] && [ -f "$root/.github/known_build.txt" ]; then
	build="$(tr -d '[:space:]' < "$root/.github/known_build.txt")"
fi
[ -n "$build" ] || build=unknown

stamp="$(date +%Y-%m-%d)"
if [ -z "$out" ]; then
	mkdir -p "$root/tests/runtime/runs"
	out="$root/tests/runtime/runs/$stamp-$build.md"
else
	mkdir -p "$(dirname -- "$out")"
fi

version="$(sed -n 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' "$root/mod/descriptor.mod" | head -1)"
[ -n "$version" ] || version=unknown

{
	printf '# Runtime run: %s\n\n' "$stamp"
	printf -- '- Build: `%s` (the value `.github/known_build.txt` held when this ran)\n' "$build"
	printf -- '- Mod version: %s\n' "$version"
	printf -- '- Runner: `tools/run_checklist.sh`\n'
	printf -- '- Verdict: **%s** — %s\n\n' "$verdict" "$reason"

	printf '| # | Test | Result | Note |\n| --- | --- | --- | --- |\n'
	for id in "${ids[@]}"; do
		status="$(row_status "$id")"
		case "$status" in
			p) label=pass ;;
			f) label=**fail** ;;
			*) label=skip ;;
		esac
		note="$(row_note "$id")"
		printf '| %s | %s | %s | %s |\n' "$id" "$(row_title "$id")" "$label" "${note:--}"
	done

	printf '\n## Tally\n\n%d pass, %d fail, %d skip.\n' "$passed" "$failed" "$skipped"
	printf '\n## Verdict\n\n**%s** — %s\n' "$verdict" "$reason"
	printf '\nFatal rows are %s; fixable rows are %s. The tiering lives in `tests/runtime/checklist.md`.\n' \
		"$fatal_rows" "$fixable_rows"

	if [ -n "$log" ]; then
		printf '\n## error.log\n\n'
		if [ -f "$log" ]; then
			hits="$(grep -c 'dlc_' "$log" 2>/dev/null || true)"
			hits="${hits:-0}"
			printf '`%s`: %s line(s) mentioning `dlc_`.\n' "$log" "$hits"
			if [ "$hits" -gt 0 ]; then
				printf '\n```\n'
				grep -n 'dlc_' "$log" | head -20
				printf '```\n'
			fi
		else
			printf 'Not found: `%s`\n' "$log"
		fi
	fi
} > "$out"

printf '\nReport: %s\nVerdict: %s (%s)\n' "$out" "$verdict" "$reason"

if [ "$post" -eq 1 ]; then
	if command -v gh >/dev/null 2>&1; then
		gh issue comment 6 --body-file "$out" && printf 'Posted to issue #6.\n'
	else
		printf 'gh not found; report left at %s\n' "$out" >&2
	fi
fi

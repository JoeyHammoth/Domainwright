# Runtime checklist

Manual, in-game verification for Domainwright. Run the whole list against a new game build before bumping
`supported_version`, and record the results next to the release notes.

Setup:

- A throwaway campaign, ironman off, debug mode on.
- A small save with three rulers: the player (duke), an AI vassal (count), and an independent AI ruler.
- `error.log` open or tailed.

Console helpers:

```
effect = { dlc_set_delta_effect = { VALUE = 8 } }
effect = { dlc_set_delta_effect = { VALUE = -3 } }
effect = { dlc_reset_effect = yes }
```

| # | Test | Pass criteria | Result |
| --- | --- | --- | --- |
| R1 | Apply +N / -N to the player | Effective limit equals natural + delta in the UI and tooltips | |
| R2 | Apply to an AI vassal | Same, and the window shows correct values for non-players | |
| R3 | Reset | All ladder modifiers removed, delta cleared, tooltip returns to natural | |
| R4 | Save, reload | Overrides persist exactly | |
| R5 | Succession, inheritance off / on | Off: heir has no override. On: heir's delta equals the predecessor's | |
| R6 | Natural limit changes (perk, title, trait) | Effective limit tracks the change in delta mode | |
| R7 | Clamp boundaries (-63, +127, and past both) | Values clamp, nothing errors, exactly the clamped rungs remain | |
| R8 | Nomad, conqueror, tribal and clan rulers | No hard-cap surprises, or documented in the issue | |
| R9 | Over-limit state | Vanilla penalties apply and the tooltip reads sensibly | |
| R10 | Mod removal after use | Save loads; cleanup effect removes every rung | |
| R11 | Other UI mods enabled | The interaction and menu still work with a UI overhaul loaded | |
| R12 | `error.log` after a play session | No new errors naming a `dlc_` identifier | |
| R13 | Event menu: repeated clicks | Readout refreshes each time, no stuck or duplicated events | |
| R14 | Widget: open, close, reopen, switch target | Readouts match the selected character, no GUI errors | |
| R15 | 50 rapid changes in a row | Exactly the expected rungs remain; none orphaned | |
| R16 | Strict-limit governments (nomadic, Mandala, Wanua, Ritsuryo, Soryo) | Works as intended, or the UI warns clearly | |
| R17 | Tooltips | Each rung appears as a named line in the domain-limit tooltip | |

## Verdict rules

The go/no-go decision for Milestone 1 reads the tier, not the tally: a run with failures can still be a go.

| Tier | Rows | A failure means |
| --- | --- | --- |
| Fatal | R1, R3, R4, R7 | **No-go.** The ladder or its persistence is wrong; revise SPEC section 3 before writing more script. |
| Fixable | R5, R6, R10, R12, R13, R14, R15, R17 | **Go**, with a follow-up issue naming the fix. The mechanism stands and the defect is local. |
| Report | R2, R8, R9, R11, R16 | **Never blocks.** These record vanilla behaviour and compatibility, not our correctness. Record what happened. |

A skipped fatal row is not a pass: if any fatal row is skipped the run is **incomplete** and the gate stays shut.

`tools/run_checklist.sh` walks this list, applies these tiers and writes the report to `tests/runtime/runs/`.

## Recorded runs

| Date | Build id | Mod version | Passed | Notes |
| --- | --- | --- | --- | --- |
| — | — | 0.1.0-dev | none yet | Not yet run in game. Reports go in `tests/runtime/runs/`. |

# AI behaviour protocol

The mod's central claim is that vanilla AI treats the edited limit as real. A tooltip proving the number changed
does not prove that, so this protocol measures behaviour.

## Setup

- Fixed test save with two AI rulers:
  - **A**: holds more counties than their natural limit allows.
  - **B**: holds fewer than their natural limit allows.
- A third AI ruler untouched, as control.
- Ironman off, fixed difficulty, no other gameplay mods.

## Runs

Three parallel campaigns from the same save:

| Run | Change |
| --- | --- |
| A-lowered | Set A's delta to `-N` (enough to put them clearly over) |
| B-raised | Set B's delta to `+N` (enough to leave them clearly under) |
| Control | Change nothing |

Fast-forward a fixed period (10 years is the default), same seed where the game allows it, repeating the whole
set at least three times because AI decisions are stochastic.

## Record per ruler

- Counties held at year 0, 1, 3, 5, 10.
- Revocations, grants and vassalisation of counties.
- Whether over-limit penalty modifiers appear.
- Any interaction the ruler initiates that targets their own holdings.

## Pass criteria

- A-lowered sheds or stops acquiring counties relative to control.
- B-raised acquires or retains more than control.
- The divergence is in the expected direction in a majority of repeats.

If the direction is right but weak, record it as "inconclusive, direction correct" rather than a pass. If the
control drifts as much as the treatment, the test is measuring noise.

## Recording results

`tests/ai/results/<date>-<build>-<modversion>.md` with the table above, plus the seed, difficulty, and the
`error.log` excerpt for anything that names a `dlc_` identifier.

## What a failure means

If the AI does not respond at all, the likely causes, in order:

1. A government `domain_limit_max` clamp (check the target's government before blaming the mod).
2. A hardcoded comparison in an AI script — classify it in `docs/ai-notes.md` and link the issue.
3. AI holdings cached before the modifier applied — test again after a month tick.

Record which one it was. "AI ignored it" is not a usable bug report.

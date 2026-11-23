# AI notes: who reads the domain limit

The headline claim of Domainwright is that vanilla AI responds to a modified domain limit because the mod edits
the same statistic the AI already reads. This file is the evidence ledger for that claim.

Method: grep the installed build (1.20.1.1) for `domain_limit`, then classify each hit as **reads the computed
stat** (our ladder works), **writes/caps it** (may override us), or **irrelevant** (loc, comment, tooltip).

Re-run with:

```bash
cd "Crusader.Kings.III.v1.20.1.1/game/game"
grep -rn "domain_limit" common/ events/ gui/ localization/english/ \
  | grep -v "^localization" > /tmp/domain_limit_sweep.txt
wc -l /tmp/domain_limit_sweep.txt
```

(Keeping the sweep out of the repo: it is derived from vanilla files.)

## Confirmed readers

| Location | What it does | Why it matters |
| --- | --- | --- |
| `common/script_values/00_difficulty_values.txt:1247` | `domain_size < domain_limit` | The difficulty/AI script value compares holdings against the computed limit, not a constant. |
| `common/script_values/00_building_values.txt:343` | `add = domain_limit` | Building value scales with the limit; a raised limit makes buildings worth more to the AI. |
| `common/scripted_rules/00_rules.txt:873` | `buildings_enabled` → `domain_size_excluding_grace_period < building_disable_inefficient_value` | AI building decisions respect the over-limit state, with vanilla's grace period. |
| `common/game_rules/00_game_rules.txt:1105` | `domain_limit_tweaks` applies `domain_limit_plus_*` | Proves the modifier path is the engine's own supported mechanism. |

## Confirmed writers / caps

| Location | What it does | Consequence |
| --- | --- | --- |
| `common/governments/00_government_types.txt:297` | `domain_limit_max = 2` in a government's `character_modifier` | Hard cap; a positive ladder may be ignored. Test R8/R16. |
| `common/governments/00_government_types.txt:1056` | `domain_limit_max = 2` for another government | Same. |
| `common/governments/00_government_types.txt:689` | nomadic `domain_limit = -1` | Different base; deltas still apply but the baseline is not tier-driven. |
| `common/modifiers/00_basic_modifiers.txt:59-112` | tier modifiers | The natural limit's main input. |
| `common/modifiers/00_basic_modifiers.txt:652-662` | `domain_limit_plus_one/two/three`, `minus_*` | Vanilla's own ladder, applied by game rule. |

## Unclassified hits

The full sweep returns ~56 files. These are the ones not yet walked line by line; each must be classified before
the AI claim is called proven:

- `common/character_interactions/` (5 files) — interactions that show or gate on the limit.
- `common/laws/00_realm_laws.txt`, `common/culture/innovations/`, `common/dynasty_perks/`,
  `common/lifestyle_perks/`, `common/religion/tenet_types/` — sources of the natural limit; they should add
  `domain_limit` themselves and therefore combine with the delta.
- `common/traits/00_traits.txt` — trait contributions (the "not inheritable" complaint from SPEC §2).
- `common/important_actions/00_realm_actions.txt`, `common/decisions/` — player-facing actions that may target
  over-limit rulers.
- `common/trigger_localization/` — tooltip-only; expected irrelevant.
- `common/casus_belli_types/`, `common/domiciles/`, `common/buildings/` — need a scope check: these may read
  `domain_limit` inside a county or title scope, where the value may not mean what we think.

## What would falsify the claim

1. An AI script that compares `domain_size` against a hardcoded integer instead of `domain_limit`.
2. A government whose `domain_limit_max` clamps before the modifier pipeline.
3. AI scheduling that never re-evaluates holdings after the modifier changes (i.e. the value is cached at
   character creation).

Observation protocol: `tests/ai/protocol.md`. Results go in `tests/ai/results/` with the game build id and mod
version, because AI behaviour is stochastic and needs repeats.

# AI notes: who reads the domain limit

The headline claim of Domainwright is that vanilla AI responds to a modified domain limit because the mod edits
the same statistic the AI already reads. This file is the evidence ledger for that claim.

Method: grep the installed build (1.20.1.1) for `domain_limit`, then assign **every** hit to one of four
classes:

1. **Reads the computed stat** — vanilla compares holdings against the limit, so the ladder is visible to it.
2. **Adds to the limit** — a source of the natural limit; those combine with the delta rather than fight it.
3. **Caps or floors it** — `domain_limit_max` / `domain_limit_min`; these can make the ladder inert.
4. **Irrelevant** — tooltip text, loc keys, documentation, commented-out lines.

Re-run with:

```bash
cd "Crusader.Kings.III.v1.20.1.1/game/game"
grep -rn "domain_limit" common/ events/ gui/ > /tmp/domain_limit_sweep.txt
wc -l /tmp/domain_limit_sweep.txt; cut -d: -f1 /tmp/domain_limit_sweep.txt | sort -u | wc -l
```

On 1.20.1.1 that returns **224 hits in 66 files** (localization excluded). Keeping the sweep out of the repo:
it is derived from vanilla files.

## Verdict

The read path is real and broader than first recorded: vanilla's AI budget effects compare `domain_size` against
`domain_limit` four times before deciding to revoke a title, build a holding or go to war. Nothing in the sweep
compares holdings to a hardcoded integer.

The write path is also broader than first recorded: **caps are not confined to two governments.** Realm laws,
lifestyle perks, buildings, domiciles, great projects and one AI conqueror modifier all set `domain_limit_min` /
`domain_limit_max`, and those clamp the computed limit. That is the finding that matters for the ladder: on a
capped ruler a positive delta can be silently absorbed, and on an extreme conqueror a negative delta can be
floored. See "Consequences for the ladder".

`domain_limit_available` is the engine's convenience trigger for `domain_limit - domain_size`; it is used all over
decisions, events and AI values, and it responds to the delta in the obvious direction.

## 1. Reads the computed stat

| Location | What it does | Why it matters |
| --- | --- | --- |
| `common/scripted_effects/00_ai_budget_effects.txt:28,384,440,592` | `domain_size < domain_limit` gates AI title revocation, booming/building and war chest spending | **Strongest single piece of evidence.** The AI's budget decision compares the computed stat, so a changed limit changes what it decides to afford. |
| `common/script_values/00_difficulty_values.txt:1247` | `domain_size < domain_limit` in a difficulty/AI script value | AI weighting reads the stat, not a constant. |
| `common/script_values/00_building_values.txt:343` | `add = domain_limit` | A raised limit makes buildings worth more to the AI. |
| `common/buildings/00_city_buildings.txt:577` | holder's `ai_value` adds 100 when `domain_limit_available < 1` | AI building preference responds to a full domain. |
| `common/great_projects/types/00_natural_disasters.txt:987,2449` | `domain_limit_available < 1` with the comment "AI will never give up domain they don't have" | Vanilla's own note that the AI reads this value before giving land away. |
| `common/important_actions/00_realm_actions.txt:77-98` | `action_above_domain_limit` alert on `domain_limit_available < 0`, opens the realm view and starts the reactive tutorial lesson | The player-facing over-limit alert is driven by the same trigger, so it fires at the new threshold. |
| `common/scripted_modifiers/00_religion_scripted_modifiers.txt:1410-1417,2333-2336` | opinion penalty `add = (domain_size - domain_limit) * -10`, gated on `domain_size > domain_limit` | Over-limit opinion damage scales with the delta, in both directions. |
| `common/character_interactions/00_grant_titles_interaction.txt:1028,1062,1071` | "not over my domain limit" gating and tooltips | Grant/revoke UI decisions respect the modified limit. |
| `common/character_interactions/00_revoke_title_interaction.txt:1139,1265,1272` | `domain_size < domain_limit` | Same. |
| `common/character_interactions/00_vassal_interactions.txt:1021` | `domain_size < domain_limit` | Same. |
| `common/character_interactions/06_ep3_laamp_interactions.txt:2558` | `domain_size > domain_limit` | Landless-adventurer path reads the stat. |
| `common/character_interactions/09_mpo_interactions.txt:7452` | `domain_size < domain_limit` | Nomad path reads the stat. |
| `common/casus_belli_types/00_nomadic_conquest.txt:46` | `domain_size >= domain_limit` | Declaring war depends on the limit. |
| `common/casus_belli_types/00_tributarize.txt:524,546` | `domain_size < domain_limit` | Tributarisation gating. |
| `common/casus_belli_types/09_mpo_wars.txt:2992,4257` | `domain_size >= domain_limit` | Migration wars. |
| `common/decisions/dlc_decisions/mpo/mpo_decisions.txt:5229,5233` | "usurp until domain limit" settle decision | AI/player decision names the limit in its own text. |
| `common/decisions/tutorial_decisions.txt:246,363,483,738,779,826` | `domain_limit_available > 0` | Tutorial only, but confirms the trigger's direction. |
| `events/relations_events/vassal_events.txt:1813,1857,1917,1994,2010,2039,2085` | seven `domain_size` / `domain_limit` comparisons | Vassal AI events fire on the relation, not a constant. |
| `events/dlc/mpo/mpo_nomad_events_1.txt:2942,2946` | `domain_limit_available <= 0` / `>= 2` | Nomad events branch on available space. |
| `events/dlc/tgp/tgp_japan_general_events.txt:543` | `domain_limit_available <= 0` | Japan events. |
| `events/dlc/mpo/mpo_migration_contract_events.txt:631` | `domain_limit_available < 0` | Migration contracts. |
| `events/court_events/court_events_general.txt:9664` | `domain_limit_available < 0` | Court events. |
| `events/mpo_misc.txt:437` | `domain_size > domain_limit` | Misc event gating. |
| `common/on_action/dlc/mpo/mpo_the_great_steppe_on_actions.txt:338` | `domain_size > domain_limit` | On-action reaction. |
| `common/scripted_effects/09_dlc_mpo_scripted_effects.txt:660,668` | `domain_limit_available < 0` | Nomad cleanup effects. |
| `common/courtier_guest_management/guest_management.txt:143` | `domain_size > domain_limit` | Guest pool gating. |
| `common/scripted_rules/00_rules.txt:873-875` | compares `domain_size_excluding_grace_period` against the script value `building_disable_inefficient_value`; the only literal is the tooltip key `vastly_over_domain_limit_trigger` | **Indirect.** The file does not read `domain_limit` itself. Building enablement follows that script value, so it must be checked separately before claiming a response. |

## 2. Adds to the limit (combines with the delta)

| Location | What it contributes |
| --- | --- |
| `common/traits/00_traits.txt` (22 hits, lines 16-1863) | Education tiers -1 / +1 / +2 / +3 and various character traits. The natural limit's largest single source. |
| `common/modifiers/00_basic_modifiers.txt:59-112` | Title-rank tier modifiers (+1 to +5). The main structural input. |
| `common/modifiers/00_basic_modifiers.txt:652-673` | Vanilla's own plus/minus ladder, applied by the game rule. Proof the modifier path is the engine's supported mechanism. |
| `common/modifiers/07_ep3_modifiers.txt:1556,1566,1575,1584` | Administrative/government modifiers adding +1 / +2. |
| `common/modifiers/00_historical_artifact_modifiers.txt:260`, `00_bookmark_modifiers.txt:10`, `10_ach_oath_modifiers.txt:39` | Single +1 contributions (artifact, bookmark, oath). |
| `common/modifiers/10_tgp_natural_disasters_modifiers.txt:276` | -1: the only vanilla *negative* contribution outside the game-rule ladder. |
| `common/lifestyle_perks/00_stewardship_2_domain_tree_perks.txt:393` | +1 for governments carrying `government_uses_domain_limit`. |
| `common/lifestyle_perks/00_martial_2_authority_tree_perks.txt:288`, `00_intrigue_3_intimidation_tree_perks.txt:221`, `00_wanderer_1_surveyor_tree_perks.txt:348` | +1 each, all flagged `government_uses_domain_limit`. |
| `common/religion/tenet_types/00_tenet_types.txt:1530,3060` | +1 per tenet. |
| `common/culture/innovations/00_late_medieval_innovations.txt:384`, `00_tribal_innovations.txt:251` | +1 per innovation. |
| `common/dynasty_perks/00_dynasty_perks.txt:210` | +1 dynasty legacy. |
| `common/buildings/tgp_great_project_buildings.txt:57,152,248,345,443` | Great-project tiers add +1 to +4 (and cap; next table). |
| `common/governments/00_government_types.txt:689` | Nomadic base -1: a different baseline, not a cap. |

Because every entry above is a `domain_limit` modifier, the delta is added on top of them. A character who gains a
perk mid-campaign keeps the override and their limit moves with the perk — the intended behaviour of SPEC §3.1.

## 3. Caps and floors (can make the ladder inert)

`domain_limit_max` and `domain_limit_min` are defined at
`common/modifier_definition_formats/00_definitions.txt:3714` and `:3718` and behave as clamps on the computed
limit, in the same family as `vassal_limit_max`.

| Location | Cap / floor | Consequence |
| --- | --- | --- |
| `common/governments/00_government_types.txt:297` | `domain_limit_max = 2` | A positive delta above 2 is absorbed. |
| `common/governments/00_government_types.txt:1056` | `domain_limit_max = 2` | Same. |
| `common/governments/01_japan_government_types.txt:47` | `domain_limit_max = 1` ("raised further by manor") | The manor is what brings it to 2; the ladder cannot go past the cap. |
| `common/governments/01_japan_government_types.txt:125` | `domain_limit_max = 2` | Same, for the shogunate. |
| `common/laws/00_realm_laws.txt:1804-1805` | nomadic authority 1: min 1, max 2 | The limit is *set* by law, not derived, for nomads. |
| `common/laws/00_realm_laws.txt:1841-1842` | nomadic authority 2: min 1, max 1 | Effectively fixed at 1. |
| `common/laws/00_realm_laws.txt:1927-1928` | nomadic authority 3: min 2, max 3 | Fixed band. |
| `common/laws/00_realm_laws.txt:2023` | nomadic authority 4: min 2, no max | Negative deltas are floored at 2. |
| `common/modifiers/00_basic_modifiers.txt:696-697` | `ai_extreme_conqueror_modifier`: min 5, max 15 | **Both directions clamped**: a conqueror cannot be dropped below 5 and cannot be raised above 15. This is the "hard cap 15 for Conquerors" community report, located. |
| `common/lifestyle_perks/00_stewardship_2_domain_tree_perks.txt:397-398,406,410,414,419` | nomadic min 1 / max 1; mandala, japan feudal, japan administrative, wanua each max 1 | Perks that *raise a cap* rather than the limit. They make the cap government-dependent, so a warning cannot be a single constant. |
| `common/lifestyle_perks/00_wanderer_1_surveyor_tree_perks.txt:353,357,361,365` | nomadic, mandala, japan administrative, japan feudal max 1 | Same pattern. |
| `common/buildings/00_tribal_buildings.txt:781,823,943,988` | wanua `character_government_modifier`: max 1 | Wanua's cap is raised by forts. |
| `common/domiciles/buildings/10_japanese_manor_buildings.txt:152,238,323` | max 1 each | Japan's manor tiers are the cap ladder. |
| `common/confederation_types/10_house_bloc_types.txt:386` | leading house head: max 1 | Confederation leaders are capped. |
| `common/buildings/tgp_great_project_buildings.txt:60,156,253,351,448` | max 1, 2, 3, 5, 7 by tier | Great projects raise the cap with their own add; the effective ceiling is the cap, not the sum. |

Reading the government files together: `government_uses_domain_limit` is a **government flag**, declared inside each
government's `flags = { }` block (`common/governments/00_government_types.txt:34,86,162,235,539,892,1211,1337`,
`02_theocratic_government_types.txt:44,136`) and read with the `government_has_flag` trigger. Its vanilla comment
(`common/lifestyle_perks/00_intrigue_3_intimidation_tree_perks.txt:220`) defines it as true for governments that do
not use `domain_limit_max` **or that hold no land**. So the capping governments are exactly the ones *without* the
flag, and landless rulers are already excluded by the flag's own definition.

The predicate is therefore `NOT = { government_has_flag = government_uses_domain_limit }` — note the trigger name and
the negation. (An earlier draft of the #8 comment had both wrong: it named a non-existent `has_government_flag` and
claimed the flag was *true* for capped governments.) It is implemented as `dlc_government_may_cap_limit_trigger`
and drives the menu warning; R8 and R16 are what confirm it per government.

## 4. Irrelevant (UI, loc, docs, comments)

| Location | Why it does not count |
| --- | --- |
| `common/game_concepts/00_game_concepts.txt:48` | Concept icon entry. |
| `common/trigger_localization/00_character_triggers.txt:1789` | Tooltip for the `domain_limit` trigger. |
| `common/trigger_localization/00_building_requirement_triggers.txt:59` | `vastly_over_domain_limit_trigger` tooltip text. |
| `common/tutorial_lessons/00_tutorial_lessons_basics.txt:2927` | `highlight_widget = "domain_limit"` — a widget name. |
| `common/tutorial_lessons/00_tutorial_lessons_reactive.txt:94-104` | Reactive advice lesson; fires from the important action above. |
| `common/diarchies/diarchy_types/00_primeministerships.txt:120` | `name = from_diarch_domain_limit_bonus` — a loc key. |
| `common/holdings/00_holdings.txt:188,201` and `common/holdings/_holdings.info:27,32` | `counts_toward_domain_limit_if_disabled = no` for nomad and herder camps: an ownership rule, not a limit modifier. It changes what counts as a holding, not the limit. |
| `common/modifiers/00_artifact_modifiers.txt:487-488` | Commented out. |
| `common/scripted_effects/00_ep1_artifact_creation_effects.txt:5853,6412` | Commented out. |
| `common/game_rules/00_game_rules.txt:1105-1165` | The engine's own `domain_limit_tweaks` rule and its modifier ladder. Already the proof of mechanism, not a competitor. |
| `gui/hud.gui:7354` | `name = "domain_limit"` widget label; the readout at `:7363-7397` uses `Character.GetDomainSize` / `GetDomainLimit`. |
| `gui/window_character.gui:1693,1726`, `gui/interaction_grant_titles.gui:118,124`, `gui/interaction_revoke_title.gui:104,109` | Widget names and readout bindings; they display the computed stat. |

## Consequences for the ladder

1. **The AI claim survives the sweep.** No AI script compares against a hardcoded integer; the budget effects,
   difficulty values and war declarations read `domain_limit` through the engine. The remaining risk is not the
   read path but whether AI re-evaluates holdings often enough to act (protocol, `tests/ai/protocol.md`).
2. **Caps are the real failure mode, and they are structural.** Nomadic rulers have their limit set by realm law
   (1-3), Japan by government plus manor (2), Mandala and Wanua at 1-2, extreme conquerors 5-15. On those
   characters the ladder is not "wrong", it is clamped — so the UI must warn rather than lie (issue #8).
3. **One predicate names them:** `NOT = { government_has_flag = government_uses_domain_limit }` is true exactly for
   the governments that cap, per the comment at `00_intrigue_3_intimidation_tree_perks.txt:220`. It ships as
   `dlc_government_may_cap_limit_trigger`; the flag's per-government truth still needs R8/R16 to confirm.
4. **Range choice is still sound:** -63..+127 is expressible, and clamping at the top of the ladder is only
   visible where a cap is lower than that.

## What would falsify the claim

1. An AI script that compares `domain_size` against a hardcoded integer instead of `domain_limit` — **none found
   in 224 hits**.
2. A government whose `domain_limit_max` clamps before the modifier pipeline — **confirmed to exist** (table 3);
   this limits scope, not the mechanism.
3. AI scheduling that never re-evaluates holdings after the modifier changes (the value cached at character
   creation) — untested; this is what the AI protocol measures.

Observation protocol: `tests/ai/protocol.md`. Results go in `tests/ai/results/` with the game build id and mod
version, because AI behaviour is stochastic and needs repeats.

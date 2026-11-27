# CK3 game internals, as read from the installed files

Research notes for Domainwright. Every claim cites a file and line in the installed game, which is **not** in this
repository. Paths are relative to the script root:

```
Crusader.Kings.III.v1.20.1.1/game/game/
```

Game version studied: **1.20.1.1**. Re-run the sweeps when `known_build.txt` changes.

---

## 1. How the game is laid out

`game/` (the Steam install root) is the executable and launcher. The **script root** is `game/game/`, and that
is where every database folder lives:

| Folder | Contents |
| --- | --- |
| `common/` | ~70 databases: modifiers, scripted effects/triggers, interactions, game rules, governments, on_actions, script values, scripted GUIs, … |
| `events/` | Event files, grouped by namespace and feature |
| `gui/` | `.gui` window definitions, plus `gui/scripted_widgets/` for mod-registered windows |
| `localization/english/` | `*_l_english.yml` string tables |
| `history/` | Characters, titles, provinces for each bookmark |
| `tests/` | Scripted in-game tests (`_tests.info` plus `.txt` cases) |
| `dlc/`, `content_source/` | DLC script and store descriptors |

`common/modifier_definition_formats/` defines *how a modifier number is displayed*; `common/modifiers/` defines
*actual character modifiers*. They are different databases and it is easy to confuse them.

## 2. The domain limit, precisely

Confirmed keys, all in `common/modifier_definition_formats/00_definitions.txt`:

- `domain_limit { decimals = 0 }` — line 840
- `domain_limit_max { decimals = 0 }` — line 3714
- `domain_limit_min { decimals = 0 }` — line 3718

So `domain_limit` is an ordinary numeric modifier, and the `_max`/`_min` variants are clamp keys, not
independent limits. **This is why the ladder design works**: adding `domain_limit = N` changes the statistic the
rest of the game reads.

### 2.1 Where the natural limit comes from

`common/modifiers/00_basic_modifiers.txt` gives the tier contributions (lines 59–112):

| Modifier | `domain_limit` |
| --- | --- |
| `baron_modifier` | 1 |
| `count_modifier` | 2 |
| `duke_modifier` | 2 |
| `king_modifier` | 3 |
| `emperor_modifier` | 4 |
| `hegemon_modifier` | 5 |
| `unlanded_modifier` | 0 |

The same file (lines 652–662) already ships `domain_limit_plus_one/two/three` and a `minus_*` family — the
engine's own precedent for exactly the ladder approach, applied through a game rule rather than per character.

### 2.2 Hard caps and strict governments

`common/governments/00_government_types.txt`:

- line 34, 86, 162, 235, 539, 892, 1211: `government_uses_domain_limit` flag — the government participates in the
  domain system at all.
- line 297 and line 1056: `domain_limit_max = 2` inside a government's `character_modifier` block — a real hard
  cap. **A ruler under such a government may ignore a positive ladder.**
- line 689: nomadic `domain_limit = -1` — nomads start from a different base.

Consequence: the ladder is necessary but not always sufficient. Strict governments are a named runtime test
(SPEC R8/R16) and the UI should warn rather than silently lie.

### 2.3 Readers of the statistic (what the AI actually sees)

| File:line | Code | Reads the computed stat? |
| --- | --- | --- |
| `common/script_values/00_difficulty_values.txt:1247` | `domain_size < domain_limit` | Yes |
| `common/script_values/00_building_values.txt:343` | `add = domain_limit` | Yes |
| `common/scripted_rules/00_rules.txt:873-883` | `buildings_enabled` compares `domain_size_excluding_grace_period < building_disable_inefficient_value` | Yes, via script value |
| `common/game_rules/00_game_rules.txt:1105-1167` | `domain_limit_tweaks` applies `domain_limit_*` modifiers | Yes — it *is* the modifier path |

The grace period is real and named: `domain_size_excluding_grace_period` exists as a script value, so vanilla
intentionally excludes recently acquired over-limit holdings from building restrictions. That matches the
tooltip text in `localization/english/game_concepts_l_english.yml:50`.

`docs/ai-notes.md` holds the full sweep and its classification.

### 2.4 The game-rule pattern to copy

`common/game_rules/00_game_rules.txt:1105` is the exact shape this mod reuses:

```
domain_limit_tweaks = {
  categories = { difficulty tweaks }
  default = domain_limit_default
  domain_limit_default = { }
  domain_limit_plus_one_player = {
    apply_modifier = player:domain_limit_plus_one
    flag = blocks_achievements
  }
  domain_limit_plus_one = { apply_modifier = all:domain_limit_plus_one }
}
```

Notes:
- `apply_modifier = <scope selector>:<modifier key>`; selectors seen are `player:` and `all:`.
- `flag = blocks_achievements` is applied per *setting*, not per rule.
- A setting can be empty (`domain_limit_default = { }`).
- Settings are read in script with the bare trigger `has_game_rule = <setting_key>`, e.g.
  `common/scripted_triggers/00_ai_value_triggers.txt:342`.

Localization naming, from `localization/english/game_rules_l_english.yml:176-190`:
`rule_<rule_key>`, `setting_<setting_key>`, `setting_<setting_key>_desc`.

## 3. Character modifiers

`common/modifiers/_modifiers.info` states the format and every optional field:

```
key = {
  icon = icon_name            # *_positive / *_negative get coloured names
  stacking = no               # keep separate instances of the same timed modifier
  hide_effects = no           # show only <key>_desc
  tax_mult = 0.25             # ...effect lines...
  scale = { value = ... desc = ... display_mode = default|scaled|unscaled }
}
```

Applying one, from `common/scripted_effects/09_dlc_mpo_scripted_effects.txt:1848`:

```
add_character_modifier = { modifier = mpo_fascination_leap_modifier years = 4 }
```

Omitting `years` gives a permanent modifier. Removal is `remove_character_modifier = <key>`, used throughout
`common/scripted_effects/00_animal_effects.txt` (e.g. line 324). Permanent modifiers therefore persist in saves
and must be actively stripped — the reason for `dlc_reset_all`.

Modifier icons live in `common/modifier_icons/00_modifier_icons.txt`.

## 4. Scripted effects, triggers and local variables

- Scripted effects are parameterised with `$PARAM$` and called by key. `common/scripted_effects/` is loaded
  wholesale; no registration file is needed.
- Local variables are available inside effects: `set_local_variable = { name = x value = ... }` and
  `change_local_variable = { name = x add|subtract|multiply|divide = ... }`, seen in
  `common/scripted_effects/00_lifestyle_focus_effects.txt:637-648`. This mod does **not** use them: a local
  variable is invisible to the tooltip dry-run pass, so the ladder tests bits of script values instead
  (section 11).
- There is **no** `clamp_variable` in the vanilla scripted effects swept; clamping is therefore done with
  explicit `if` guards around `set_variable`.

## 5. Scripted GUIs and the GUI bridge

Examples:

- `common/scripted_guis/00_character.txt` — minimal shape: `scope = character`, `effect = { trigger_event = ... }`.
- `common/scripted_guis/ep2_activities.txt` — `saved_scopes = { host }` and an `is_valid` block.
- `common/scripted_guis/ce1_funeral_scripted_guis.txt` — an `effect` that mutates a variable list.

GUI-side call syntax, verified in vanilla `.gui` files:

```
onclick = "[GetScriptedGui('funeral_fill_available_targets_gui').Execute( GuiScope.SetRoot( GetPlayer.MakeScope ).End )]"
```

(`gui/activity_window_widgets/funeral_deceased_selection_button.gui:27`)

```
datacontext = "[GetScriptedGui( 'rename_character_after_birth' )]"
onclick = "[ScriptedGui.Execute( GuiScope.SetRoot( GetPlayer.MakeScope ).AddScope( 'child', Character.MakeScope ).End )]"
```

(`gui/interaction_menu_window.gui:372-374` — note that inside a `datacontext` the widget calls `ScriptedGui`
bare, and that `AddScope` passes an extra scope into the scripted GUI.)

Visibility checks use the tooltip/valid families on the same call chain:

```
visible = "[GetScriptedGui( 'pam_is_papabile_populist' ).IsShown( GuiScope.SetRoot( Character.MakeScope ).End )]"
```

(`gui/window_cardinals.gui:381`)

The spec's claim that `Execute`, `IsValid` and `IsShown` exist with `GuiScope` chains is confirmed for
`Execute` and `IsShown`. `ExecuteTooltip` was **not** found in a sweep of `gui/` on this build — treat as
unverified.

## 6. Scripted widgets (custom windows)

`gui/scripted_widgets/_scripted_widgets.info` is the whole registration format:

```
gui/test_custom_widget.gui = my_first_cool_test_widget
gui/test_custom_widget.gui = my_second_cool_test_widget
```

One line per widget, all files in the folder are loaded, and several mods can each register their own widget as
long as they don't collide on paths. The widget itself is a normal `window = { ... }` block, e.g.
`gui/window_character_focus.gui`:

```
window = {
  name = "character_focus_window"
  size = { 520 880 }
  parentanchor = center
  layer = middle
  using = Window_Background
  using = Window_Decoration
  vbox = { using = Window_Margins  ... }
}
```

`using =` pulls in a template from `gui/shared/`. Buttons are `button = { ... onclick = "..." }` and text is
`text = "loc_key"` or `text = "[DataFunction]"`.

**Opening a registered widget on demand remains unresolved.** The widget exists from startup; whether it can be
shown and hidden from script depends on a visibility expression over a character flag/variable. That is
Milestone 3b, and Layer 1 exists so the mod is usable either way.

## 7. Character interactions

`common/character_interactions/_character_interactions.info` documents the fields. The shape used by this mod:

```
my_interaction = {
  category = interaction_category_vassal     # required
  common_interaction = yes
  desc = my_interaction_desc
  is_shown = { ... }
  is_valid_showing_failures_only = { ... }
  on_accept = { ... }
}
```

`interface_priority` sorts within a category; `icon` defaults to `<key>.dds`; omitting `interface` uses the
default interaction window. `on_accept` runs in actor scope with `scope:recipient` available, which is how
`00_vassal_interactions.txt:1589-1591` fires an event on the recipient:

```
scope:recipient = { trigger_event = faction_invitation.0001 }
```

Events triggered this way receive the target as their root, and previously `save_scope_as`-ed scopes remain
readable (same file, lines 1587–1590 save `scope:faction_target` before triggering).

## 8. On_action hooks

`common/on_action/_on_actions.info` documents the structure and the engine pulses. Hooks relevant here, with
their definitions:

| Hook | File:line | Root scope |
| --- | --- | --- |
| `on_death` | `common/on_action/death.txt:7` | dying character |
| `on_title_gain` | `common/on_action/title_on_actions.txt:233` | character gaining the title |
| `on_title_gain_inheritance` | `common/on_action/title_on_actions.txt:3328` | inheriting character |
| `on_title_gain_usurpation` | `common/on_action/title_on_actions.txt:3406` | usurper |
| `on_vassal_gained` | `common/on_action/title_on_actions.txt:4791` | liege |
| `on_game_start` | `common/on_action/game_start.txt:2` | — |

`on_title_gain_inheritance` is the correct succession hook for the inheritance feature: it names the case
("gained by inheritance") instead of inferring it from a death event. `on_death` is still useful for cleanup of
the dying character's modifiers, since permanent character modifiers do not follow the title.

`on_action` entries are additive by design: `events = { ... }` lists append, and new named on_actions can be
declared freely. Never rewrite a vanilla block.

## 9. Localization

File header requirement, verified byte-wise (`od -c localization/english/game_rules_l_english.yml`):

```
357 273 277  l _ e n g l i s h :  \n
```

That is: **UTF-8 BOM, then `l_english:`**. Each entry is `key:0 "value"` (the number is a version/format tag).
`\n` inside a value is a literal newline escape; `#high ... #!`, `#EMP ... #!` are inline colour/emphasis
markup. Loc references use `[domain_limit|E]` for a concept link and `$game_concept_domain_limit$` for reuse of
another string.

Decoration keys are `<key>:0` for the name, `<key>_desc:0` for the description. Game rules use
`rule_`/`setting_` prefixes as noted above.

## 10. Static-check implications

The traps the structure checker enforces come directly from the above:

1. `common/on_action` is singular; `common/on_actions` silently does nothing.
2. `localization` is American; `localisation` silently does nothing.
3. Loc files need the BOM — without it the first key is swallowed.
4. Modifier keys must exist in `common/modifiers/` **and** have localization, or the tooltip shows the raw key.
5. `supported_version` must match the installed build or the launcher warns.

## 11. The tooltip dry-run pass

While an event option or a character interaction is on screen, the game builds its tooltip by dry-running every
effect behind it. That pass **evaluates every `limit` it reaches and executes nothing**. Each row below was
observed on 1.20.1.1:

| Observation | What it means |
| --- | --- |
| `set_variable` and `set_local_variable` are not executed | a variable a preceding effect would have set is still unset in the pass, so a `limit` reading it logs three errors per refresh: "Failed to fetch variable ...", "Event target link 'local_var' returned an unset scope", "Invalid left side during comparison 'local_var'" (47,817 lines in one session) |
| `hidden_effect` is walked like any other effect | wrapping the call only moved the error to the wrapping line |
| `show_as_tooltip` executes without a tooltip entry, and is walked too | wrapping the four delta options raised the count to 249 and pinned every stack to the interaction's `on_accept` |
| `trigger_event` is expanded into the target event, and that event's `immediate` is walked | splitting the work into an immediate did not avoid the pass |
| `exists = var:x` is safe | false, not an error, in the pass and at runtime; the only variable access allowed in a limit |
| script values are not evaluated in the pass | a limit may read any script value freely |

The rule that follows: **no `limit` reachable from an option or an interaction may read a variable.** The delta
therefore exposes itself as script values (`mod/common/script_values/dlc_domain_limit_values.txt`) built on one
`exists`-guarded read, and the ladder tests bits of those values instead of carrying a remainder in a local.

### 11.1 A hand-off that does not survive

An earlier version had each option record its step in `var:dlc_pending` and re-fire the event, applying it in the
immediate. The pass was clean, but the step never landed: an exit autosave held `dlc_pending` on three characters
with no `dlc_delta` and no ladder modifier anywhere in it. Self-re-firing from an option is legal in vanilla (7
events do it), so the failure is specific to this chain rather than to the pattern; options now apply their step
directly, which is safe precisely because of the rule above.

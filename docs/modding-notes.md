# Modding CK3: what this repository assumes

Everything here is either confirmed against the installed game (see `docs/game-internals.md`) or explicitly
marked **[Verify]**.

## Loading model

A mod is a folder with `descriptor.mod` at its root. The launcher reads the descriptor, checks
`supported_version` against the game, and mounts the folder's script directories ahead of the vanilla ones.

```
mod/
├── descriptor.mod
├── .metadata/metadata.json
├── common/       # merged with vanilla common/
├── events/
├── gui/
└── localization/english/
```

Two rules follow from "merged":

1. **Same path overrides, different path adds.** A file at a vanilla path replaces it wholesale; a new file name
   inside a vanilla folder adds to it. This mod only adds files.
2. **Load order matters between mods.** Two mods adding to the same folder both load; two mods shipping the same
   file name fight, and the later one wins. Every file here is uniquely named.

### `descriptor.mod`

```
version="0.1.0"
tags={
	"Gameplay"
	"Utilities"
}
name="Domainwright"
supported_version="1.20.*"
```

`name`, `version` and `supported_version` are required. `tags` feed the launcher/Workshop categories. A `path=`
line is only needed for mods registered outside the user mod directory. **[Verify]** the launcher's exact
tolerance for wildcard versions before release; `1.20.*` is the conventional form.

### `.metadata/metadata.json`

The launcher's own copy of the same facts, used by the Playset UI. The fields this repo ships (name, version,
supported_version, tags, short description) are the ones the launcher displays; the file's full schema is
undocumented and version-sensitive. **[Verify]** against a mod exported by the current launcher before the first
release — that export is the cheapest ground truth.

## Script language essentials

- Files are `key = { ... }` trees; whitespace is insignificant; `#` starts a comment.
- Scripted effects/triggers are called by key, with `$PARAM$` substitution:
  `dlc_change_delta = { VALUE = 5 }`.
- Scopes: `scope:actor`, `scope:recipient`, saved scopes via `save_scope_as = name`, and `var:`/`local_var:`
  for variables. Saved scopes survive into an event fired by `trigger_event` from the same chain.
- Character modifiers are applied with `add_character_modifier = { modifier = key years = N }`; without `years`
  they are permanent and must be removed with `remove_character_modifier = key`.
- Localization is a separate database: a script key with no loc shows as the raw key.

## Additive-scripting rules used here

1. New identifiers only, all `dlc_`-prefixed.
2. Never redefine a vanilla on_action/effect/trigger/game rule. Add a new key instead.
3. Never ship `window_character.gui` or any other vanilla GUI path.
4. Never ship a file whose name already exists in the game, unless it is listed in the allowlist in
   `tools/check_structure.py` (currently empty).
5. Keep GUI logic thin: a `.gui` change is the most patch-fragile thing in a mod, so the scripted effects are the
   source of truth and the window is a view over them.

## Debugging workflow

1. Launch with `-debug_mode` (or enable debug in the launcher), then open the console with `` ` ``.
2. `script_docs` dumps trigger/effect/scope documentation into `logs/`.
3. `DumpDataTypes` dumps data functions — the authority for what GUI can read.
4. `effect = { ... }` and `trigger = { ... }` can be run directly from the console in the current scope, which is
   how the ladder was designed to be smoke-tested: apply `dlc_set_delta = { VALUE = 8 }` to the player and read
   the domain limit tooltip.
5. Errors land in `Documents/Paradox Interactive/Crusader Kings III/logs/error.log`; filter for `dlc_`.

Console smoke tests (Milestone 1):

```
effect = { dlc_set_delta = { VALUE = 8 } }
effect = { dlc_set_delta = { VALUE = -3 } }
effect = { dlc_reset = yes }
```

Expected: the tooltip gains a *Domain Limit* line per active bit, and the effective limit equals natural + delta.

## The in-game test harness

The install ships `tests/` with `_tests.info` and case files (`000_council.txt`, `200_qa_inheritance_tests.txt`,
…). These are scripted assertions the developers run. They are a plausible route to automated runtime tests for
this mod, but the harness's invocation and mod support were not verified in this research. **[Verify]** before
investing; until then runtime testing stays manual, per `tests/runtime/checklist.md`.

## Common traps

| Trap | Effect |
| --- | --- |
| `localisation/` instead of `localization/` | Strings silently missing |
| UTF-8 without BOM in a loc file | First key swallowed, often reported as "missing loc" |
| `common/on_actions/` | Hooks never fire |
| Missing `desc`/`name` loc key for an interaction | Interaction menu shows the raw key or crashes the tooltip |
| Permanent modifier never removed | Invisible stat change that survives save/load and uninstall |
| Editing a vanilla file "just to add one line" | Breaks every other mod that touches it; unmergeable in practice |
| A `domain_limit_max` government | Positive ladder appears to do nothing |

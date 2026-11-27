# Changelog

All notable changes to Domainwright are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Mod skeleton that loads from `mod/descriptor.mod`, with launcher metadata and a pinned
  `supported_version`.
- The `domain_limit` modifier ladder: positive bits `+1, +2, +4, +8, +16, +32, +64` and negative bits
  `-1, -2, -4, -8, -16, -32`.
- `dlc_apply_delta`, which removes the whole ladder and re-adds exactly the bits summing to `dlc_delta`;
  `dlc_set_delta`, `dlc_change_delta`, `dlc_reset` and `dlc_reset_all`.
- A **Domain Limit…** character interaction and the `dlc_menu.0001` event menu with `-5`, `-1`, `+1`, `+5`,
  reset and close.
- Game rules `dlc_access` (anyone / player only / player and realm) and `dlc_inheritance`
  (none / heir inherits delta), with an `on_title_gain` hook for inheritance.
- A registered scripted widget window and scripted GUIs for the Layer 2 interface (behind the
  `dlc_window_open` flag).
- Static validation: `tools/check_structure.py`, a `static` workflow, a self-hosted `validate` workflow with a
  ck3-tiger baseline, a Steam build-id watcher and a tagged release packager.
- Repository documentation: research notes in `docs/`, a runtime checklist, an AI behaviour protocol, the
  GitHub Pages site, and the wiki.
- A cap warning in the menu for characters whose government can clamp the computed limit, keyed off
  `government_uses_domain_limit` rather than a list of government names.
- `tools/run_checklist.sh`, which walks the runtime checklist, prints the console line for each row, applies the
  fatal / fixable / report tiers and writes a report to `tests/runtime/runs/`.

### Changed

- The ladder is rebuilt from script values instead of a greedy remainder loop: thirteen independent bit tests
  over the new `common/script_values/dlc_domain_limit_values.txt`, and no local variable anywhere in the mod.
- Delta options apply their step directly. The `var:dlc_pending` hand-off and the event `immediate` that
  consumed it are gone.

- The cap predicate is negated: `government_uses_domain_limit` is true for governments that do *not* cap, so the
  warning fires on its absence (`government_has_flag` is the trigger that reads it).

- The touch-point ledger is complete: all 224 `domain_limit` hits in build 1.20.1.1 are classified in
  `docs/ai-notes.md`, and the caps that can clamp the ladder are now listed by file and line.
- The slider gate is closed on evidence rather than left open: vanilla sliders are scrollbar parts bound to engine
  settings, no value-change callback exists, and GUI code cannot write a script variable (SPEC §3.7).

### Fixed

- Script errors while building tooltips and descriptions. While an option or interaction is on screen the engine
  dry-runs the effects behind it and evaluates every reachable `limit`, but executes nothing, so a limit that
  read a variable logged three errors per refresh (47,817 lines in one session). Every limit now reads a script
  value; the only variable access left is behind `exists =`, which is false rather than an error. A full session
  on build 1.20.1.1 afterwards produced no error naming a `dlc_` identifier.
- The delta hand-off never landed. An exit autosave held `dlc_pending` on three characters with no `dlc_delta`
  and no ladder modifier anywhere in it; options now apply the step themselves.
- `is_player = yes` replaced with `is_ai = no`. `is_player` is not a trigger in 1.20.1.1 and evaluated false,
  which made the player-only access settings match nobody.
- Removed `target_type = character`: only `title`, `artifact`, `men_at_arms` and `court_position_type` accept it.
- Removed `else_if` from a scripted trigger, where it is not a valid key and discarded the whole trigger.
- Withheld the menu's `open_window` option: `dlc_sg_open_window` is a scripted GUI, not an effect, so calling it
  from script logs "Unknown effect".
- Dropped the `on_death` hook, which replaces vanilla's `effect` block on that hook rather than extending it.
- `dlc_remaining` is initialised before its first read.

### Known limitations

- Only the log-level gate has been observed. A live session on build 1.20.1.1 loads, opens the menu and quits
  with no error naming a `dlc_` identifier (R12); the hand-recorded report is
  `tests/runtime/runs/2026-11-27-0.md`. The ladder's visible effect (R1, R3, R4, R7) is still unobserved, so
  Milestone 1 of `SPEC.md` stays open.
- `domain_limit_max` and strict-government rules may override the ladder; see the strict-government issue.
- Multiplayer is unsupported. The slider is not shipped; the interface is button-driven.

[Unreleased]: https://github.com/JoeyHammoth/Domainwright/commits/main

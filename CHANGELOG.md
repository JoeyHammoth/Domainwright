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

### Changed

- The touch-point ledger is complete: all 224 `domain_limit` hits in build 1.20.1.1 are classified in
  `docs/ai-notes.md`, and the caps that can clamp the ladder are now listed by file and line.
- The slider gate is closed on evidence rather than left open: vanilla sliders are scrollbar parts bound to engine
  settings, no value-change callback exists, and GUI code cannot write a script variable (SPEC §3.7).

### Known limitations

- Nothing here has been validated in a running game yet. Milestone 1 of `SPEC.md` is the gate.
- `domain_limit_max` and strict-government rules may override the ladder; see the strict-government issue.
- Multiplayer is unsupported. The slider is not shipped; the interface is button-driven.

[Unreleased]: https://github.com/JoeyHammoth/Domainwright/commits/main

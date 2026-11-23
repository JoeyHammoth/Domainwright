# Domainwright

**A Crusader Kings III mod that hands you the domain limit dial.**

[![static checks](https://github.com/JoeyHammoth/Domainwright/actions/workflows/static.yml/badge.svg)](https://github.com/JoeyHammoth/Domainwright/actions/workflows/static.yml)

**[Website](https://joeyhammoth.github.io/Domainwright/)** · **[Wiki](https://github.com/JoeyHammoth/Domainwright/wiki)** · **[Spec](SPEC.md)**

Domainwright lets you raise or lower any character's **domain limit** — yours, your vassals', a rival's — and
have the game treat the new number as real. Because the override is expressed as ordinary `domain_limit`
character modifiers, the vanilla penalties, tooltips and AI all read it without any AI script being replaced.

> **Status: 0.1.0-dev, pre-release.** The scripted core and the Layer 1 menu exist and pass static checks.
> They have **not** yet been validated in a running game (Milestone 1's go/no-go gate in
> [SPEC.md](SPEC.md)). Do not install this on a campaign you care about yet. See
> [Known issues](#known-issues).

---

## What it does

- **Set a delta, not a number.** The mod stores how far above or below a character's *natural* limit you want
  them (`dlc_delta`) and expresses it with a power-of-two ladder of `domain_limit` modifiers. When the
  character gains a perk or a title, their limit keeps tracking it — the override rides along.
- **Works on anyone.** Player, vassal, rival, independent ruler.
- **Leaves vanilla alone.** No vanilla file is overridden, every identifier is prefixed `dlc_`, and the mod
  never touches `window_character.gui`.
- **Survives succession, if you want it to.** A game rule decides whether the heir inherits the override.

## Install

1. Download the release zip from [Releases](https://github.com/JoeyHammoth/Domainwright/releases).
2. Unzip it so the folder containing `descriptor.mod` sits in your CK3 mod directory:
   - Windows: `Documents/Paradox Interactive/Crusader Kings III/mod/domainwright/`
   - macOS: `~/Documents/Paradox Interactive/Crusader Kings III/mod/domainwright/`
   - Linux: `~/.local/share/Paradox Interactive/Crusader Kings III/mod/domainwright/`
3. Launch CK3, open **Mods**, enable **Domainwright**, and start (or load) a campaign.

If you are running from source, copy the contents of `mod/` into that folder — `descriptor.mod` must be at its
root.

## How to play

1. Open a character's interaction menu (right-click their portrait).
2. Choose **Domain Limit…**.
3. The menu shows the character's current delta and the controls:
   - `-5`, `-1`, `+1`, `+5` adjust the override.
   - **Reset** removes the override entirely.
4. Each click re-opens the readout, so you can keep clicking until the number is where you want it.

The delta is clamped to **-63 … +127** (the range the ladder can express). Going over a limit on purpose is
allowed — vanilla's over-limit penalties apply exactly as they normally would, which is the point.

## Game rules

| Rule | Settings | Default |
| --- | --- | --- |
| **Domain Limit access** | Anyone / Player only / Player and realm | Anyone |
| **Domain Limit inheritance** | None / Heir inherits delta | None |

Both are set at campaign start, like any CK3 game rule.

## Uninstalling

The mod stores a character variable and up to seven temporary character modifiers. Before removing it from a
campaign, open the menu on each edited character and press **Reset**. Removing the mod without resetting leaves
harmless but invisible modifiers behind — see the runtime checklist for the verification step.

## Known issues

- **Not yet validated in game.** Milestone 1 of [SPEC.md](SPEC.md) is the gate; until it passes, treat every
  behaviour above as designed rather than observed.
- **`domain_limit_max` can beat the ladder.** The cap is not rare: governments cap at 1-2
  (`common/governments/00_government_types.txt:297,1056`, `01_japan_government_types.txt:47,125`), nomadic
  authority laws fix the limit at 1-3 (`common/laws/00_realm_laws.txt:1804-2023`), and vanilla's extreme
  conqueror modifier clamps to 5-15 (`common/modifiers/00_basic_modifiers.txt:696-697`). On those characters a
  delta is clamped, not applied. Tracked in the strict-government issue; the full list is in
  [`docs/ai-notes.md`](docs/ai-notes.md).
- **Achievements.** Cheat-style edits are expected to block achievements; the mod applies
  `blocks_achievements` to its game rule the way vanilla's domain-limit tweak rule does.
- **Multiplayer** is unsupported until tested.
- **No slider, and not by omission.** Vanilla's sliders are scrollbar parts bound to engine settings, no
  value-change callback exists, and GUI code cannot write a script variable — so a dragged number has no route
  into script. Verified against 1.20.1.1; see SPEC §3.7. The buttons are the interface.

## Repository map

| Path | What lives there |
| --- | --- |
| `SPEC.md` | The authoritative design, plan, test matrix and CI/CD rules |
| `mod/` | Exactly what ships; `descriptor.mod` at its root |
| `docs/` | Research notes on the game's internals, AI reads, and mod-loading rules |
| `tests/` | Static, runtime and AI-behaviour test material |
| `tools/` | Structure checker, Steam build probe, release packager |
| `site/` | The GitHub Pages site |

## Contributing

Bug reports, compatibility reports and test-save observations are all welcome — see
[CONTRIBUTING.md](CONTRIBUTING.md). Please never attach vanilla game files to an issue.

## License

[MIT](LICENSE). Crusader Kings III is a trademark of Paradox Interactive. This mod is unofficial and is not
endorsed by Paradox.

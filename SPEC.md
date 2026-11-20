# Domain Limit Control — a Crusader Kings III mod

Planning, design, implementation, testing, distribution and CI/CD specification.

- Status: draft v0.2 (planning; UI and logic research folded in)
- Target game: Crusader Kings III (Steam App ID 1158310)
- Spec date: 2026-11-21
- Conventions: **[Verify]** marks a claim that comes from general modding knowledge or a single community source and must be confirmed against current game files or documentation before it is relied on. Nothing marked [Verify] has been tested.

---

## 1. Summary

Add an in-game control that lets the player set the **domain limit** of any character, with the **AI treating the changed limit as real** (it sheds, avoids or acquires counties according to the new value, with no AI script rewrites).

The core idea is that the game computes domain limit from character modifiers. If the mod expresses its override as ordinary `domain_limit` character modifiers, every vanilla system that reads the limit (penalties, UI tooltips, AI scripts) sees the new value automatically.

### Goals

1. A UI window to view and change a character's domain limit (player, vassals, any character).
2. The override flows through the game's own domain-limit calculation so vanilla AI and penalties respond to it.
3. Overrides persist in saves, survive reloads, and behave sensibly on succession.
4. Safe to add to and remove from an existing campaign as far as the engine allows.
5. A public GitHub repo with automated validation that is re-run when the game updates.

### Non-goals (v1)

- Changing duchy/kingdom/empire title limits or vassal limits (separate systems; see section 9).
- Rebalancing the economy around domain limit.
- Multiplayer support. Treat as unsupported unless proven.
- Editing counties, culture, faith or de jure titles (covered by existing cheat/de jure mods).

---

## 2. Feasibility and prior art

| Question | Finding |
| --- | --- |
| Can a mod set domain limit? | Yes. `domain_limit` is a modifier key. A Paradox forum answer shows a character modifier with `domain_limit = 1000` applied through a game rule. |
| Can a mod add its own window? | Yes. Since patch 1.5 mods can define their own GUI windows and register them in `gui/scripted_widgets` (Dev Diary #87). |
| Is there precedent for UI-driven edits? | Yes. Cheat-menu mods (Divine Intervention, Advanced Cheat Menu) add editors through character interactions plus event/effect scripting. |
| Are there known pitfalls with domain-limit mods? | Yes. See below. |
| Is there a path from a GUI button to a script effect? | Yes. Scripted GUIs define `scope`, `is_shown`, `is_valid` and `effect` blocks. A GUI calls them with `Execute`, `IsValid` and `IsShown` (plus tooltip variants). The ck3-tiger validator's source shows the expected call shape: a `GuiScope.SetRoot(...)` chain, optional `AddScope`, ending in `End`. |
| Can a GUI read a mod's own variables? | Yes. A community snippet reads a script variable inside GUI with `GetPlayer.MakeScope.Var('name').GetValue`. |
| Is there a ready-made slider widget for mods? | **Not confirmed.** Needs a spike (section 3.7). |
| Did the domain-limit rules change recently? | Yes. Patch 1.19 reworked them (stewardship removed, education added, regencies no longer add), and several governments use stricter rules (section 2.1). |
| Can the game's update be detected automatically? | Yes, via SteamCMD `app_info_print` build id (section 8). |
| Can CI validate CK3 mods? | Yes, using `ck3-tiger`, but it needs vanilla game files, which cannot be published (section 8). |

### Pitfalls seen in an existing "virtually infinite domain" mod's comments

These are community reports, not verified, but they are exactly the failure modes to test for:

- A hard cap (reported as 15 for Conquerors) can override a modifier-based limit. [Verify]
- Nomads/Mongol-style rulers have their own limit rules that interact with modifiers. [Verify]
- The UI can show an "above maximum" negative entry even when the total looks correct, so tooltips need checking.
- A trait-based solution was not inheritable, which users disliked. Our design addresses inheritance explicitly.
- Domain limit and duchy limit are separate; raising one lets AI rulers hoard the other.

### 2.1 How domain limit is computed today

Source: secondary guides (one published 2026-11-10 citing the wiki and patch notes). **Verify every number against the game files and the current wiki before encoding any assumption.**

- Patch 1.19 removed stewardship from the calculation. Education tier now contributes: tier 1 gives -1, tier 2 gives 0, tier 3 gives +1, tier 4 gives +2, tier 5 gives +3 (as reported).
- Other contributors: title rank (reported King +3, Emperor +4, Hegemon +5), lifestyle perks, innovations, dynasty legacy, religious tenets. Regencies no longer inflate a regent's limit.
- Nomadic, Mandala, Wanua, Ritsuryo and Soryo governments reportedly use stricter limits (a nomad starts at 2 and grows with dominance levels). These may not respond to a plain modifier the same way.
- Going over the limit applies debuffs (vassals, levies, taxes) that scale with the excess and hit all counties, with a one-year grace period for newly acquired counties (older guide; confirm current behavior).
- The same 2026 guide says a DLC was announced for 2026-11-17 that adds county-tier republics with a very constrained domain limit. I did not verify whether a patch has shipped. Treat Milestone 0 as running against the newest build, and expect `supported_version` to need a bump.

Design consequences:

1. The natural limit is a sum of many sources, so a **delta modifier** (section 3.1) is the right approach; an absolute number would drift out of date.
2. Strict-government rulers are a named test case (R8, R16).
3. Over-limit penalty loc keys exist in vanilla (for example `DOMAIN_LIMIT_OVERRUN_LEVY_PENALTY`, seen in a forum thread), which is a handle for finding every script that reads the limit.

### 2.2 UI and scripting mechanics found in research

- **Scripted widgets** (patch 1.5, Dev Diary #87): a mod defines a new window in a `.gui` file and registers it with a line in `gui/scripted_widgets`; it then appears like a code-supported window. The diary frames this for custom values such as a mod's own score or resource.
- **Scripted GUIs** connect GUI to script: they declare a root `scope` and optional `is_shown`, `is_valid`, `effect` blocks. Per ck3-tiger's source, the GUI-side calls are `Execute`, `ExecuteTooltip`, `IsValid`, `IsValidTooltip`, `IsShown`, `IsShownTooltip`, `BuildTooltip`, each taking a `GuiScope.SetRoot(...)` chain.
- **Data models** (Dev Diary #126): GUI can slice a data model with `DataModelFirst`, `DataModelSkipFirst`, `DataModelSubSpan`, and set a data context from a model item with `datacontext_from_model`. Useful if the window lists multiple characters or presets.
- **Event-window and activity-window widgets** are other injection points (widget files under dedicated gui folders), which is how some mods add widgets into existing windows.
- **Existing cheat mods prove the pattern.** Divine Intervention merged its editors into one tabbed character-editor window built from templates (so compatibility patches can replace one tab), and its earlier versions drove menus through events with paged option lists. Read these mods for structure; do not copy their code without the author's permission and credit.
- **UI overhaul conflicts are real.** Users report overhaul mods breaking or being broken by other GUI mods. One overhaul hub mod splits the vanilla character window into small modules specifically so others stop fighting over `window_character.gui`.
- **Ground-truth tooling.** The game can dump its own trigger/effect/scope documentation (`script_docs`) and data-type listings (the `DumpDataTypes` console command) into the logs folder, and the game directory ships `.info` format documents per script folder. Toolkit extensions for VS Code consume these dumps and include a GUI widget tree, layout preview and visual editor. Use the dumps as the authority over any wiki page or this spec.

---

## 3. Design

### 3.1 Override mechanism: modifier ladder

A `domain_limit` modifier has a fixed value, so a slider cannot set an arbitrary number directly. Instead:

1. Store the desired **delta from the character's natural limit** in a character variable, `dlc_delta`.
2. Maintain a small set of fixed-value modifiers (a "ladder"):
   - Positive bits: `+1, +2, +4, +8, +16, +32, +64`
   - Negative bits: `-1, -2, -4, -8, -16, -32`
3. A scripted effect, `dlc_apply_delta`, removes all ladder modifiers from the character, then adds the bit-modifiers that sum to `dlc_delta`.
4. Range: for v1, clamp the delta to `-63..+127`. Configurable via a game rule later.

Why a delta and not an absolute value: the natural limit changes with stewardship, perks, titles and traits. A delta keeps the character's limit tracking those changes while honoring the override. The UI can display both the natural limit and the effective limit, and the user can type or slide to a target; the mod converts target to delta using the current natural limit. An "absolute lock" mode (re-derive the delta periodically so the effective limit stays fixed) is a later option.

Modifier removal and re-adding on each change keeps saves clean. Use a single modifier category prefix, `dlc_`, so cleanup is a simple removal loop.

### 3.2 AI integration

- Because the override is a normal `domain_limit` modifier, vanilla AI code that compares holdings to the limit sees the new value. **No AI script is replaced**, which avoids compatibility problems.
- AI characters are edited the same way as the player edits anyone: by selecting them in the UI. The mod does not randomly change AI limits.
- Verification must prove behavior, not just value: after lowering an AI ruler's limit, observe over time whether the AI sheds or stops acquiring counties, and whether vanilla over-limit penalties appear in their tooltip. See the AI test plan in section 6.
- Known risk: any mod or vanilla script that hardcodes a limit instead of reading the computed stat will not respond. Document these when found.

### 3.3 Persistence and inheritance

- Modifiers and variables on a character persist in save games.
- Add a game rule `dlc_inheritance`: `none` (default, matches vanilla expectations), `heir_inherits_delta`.
- When enabled, an `on_action` hook on succession copies `dlc_delta` to the new ruler and re-runs `dlc_apply_delta`. Use append-style on_action hooks, never overwrite vanilla entries.
- Removing the mod mid-campaign leaves orphaned modifiers/variables. Ship a documented "reset all" interaction that clears ladder modifiers from every character, to run before uninstalling. [Verify that orphaned modifiers are harmless on load.]

### 3.4 UI

**Phase 1 (required): button-driven window.**

- A character interaction, "Domain limit...", opens a menu for the target character: an event-based menu first, a scripted widget window as the upgrade (section 3.6).
- The window shows: natural limit, override delta, effective limit, current holdings count, and over/under status.
- Controls: `-1`, `+1`, `-5`, `+5`, "Reset", and presets. All buttons call a scripted effect that updates `dlc_delta` and reapplies the ladder.

**Phase 2 (stretch): true slider.**

- Gated by the slider spike in section 3.7. If the spike fails, keep the button UI; it is functionally equivalent and lower risk.
- Button-to-effect binding goes through scripted GUIs (section 2.2); copy the exact call syntax from vanilla GUI files, not from this spec.

**UI integration rules:**

- Own window plus interaction entry, rather than editing the vanilla character window. This avoids conflicts with UI overhaul mods that replace that window.
- Provide localization keys for every string; ship English first.
- Prefix every identifier with `dlc_` to avoid collisions.

### 3.5 Access control

Game rule `dlc_access`:

- `anyone` (edit any character; cheat-style, default for a sandbox mod)
- `player_only` (only the player character)
- `player_and_realm` (player plus characters in their realm)

Using the mod should be documented as disabling achievements (see section 5, Known behaviors).

### 3.6 UI architecture: three layers, built in this order

**Layer 1: event-driven menu (ships first).** Cheat-menu mods run editors through events with option buttons, so this path is proven and survives patches well.

- A character interaction "Domain limit..." fires event `dlc_menu.0001` with the target saved as a scope.
- The event text shows natural limit, delta, effective limit and holdings. Options: `-1`, `+1`, `-5`, `+5`, presets, reset, close.
- Each option runs `dlc_apply_delta`, then re-fires the event so the readout refreshes.
- Pros: no GUI code, robust, tooltips through localization. Cons: window re-opens on each click, fixed layout.

**Layer 2: custom scripted widget window (upgrade).**

- A `.gui` window registered in `gui/scripted_widgets`, with the same controls plus live readouts.
- Buttons call scripted GUI `dlc_sg_change` through `Execute`; enable/disable states use `IsValid`; tooltips use the tooltip variants.
- Readouts: `Var('dlc_delta').GetValue` for the override; natural and effective limit via data functions found in the `DumpDataTypes` output. If no data function exposes the limit, compute it in script and store it in a variable the GUI can read. [Verify]
- Structure it as templates per section (header, readout, controls) so compatibility patches can replace one part, following the pattern used by existing cheat menus.

**Layer 3: optional integrations.** A small readout in the character window, delivered as a separate optional module or compatibility patch so the main mod never overrides `window_character.gui`.

**Opening the window [Verify].** Research did not confirm how a scripted widget is shown on demand. Candidates: (a) bind the widget's visibility to a flag that an interaction sets, or (b) copy whatever mechanism Divine Intervention uses to open its editor. Resolve this in Milestone 3b. Layer 1 means the mod works even if this fails.

### 3.7 Slider spike (decision gate)

Goal: decide whether a true slider is worth shipping.

1. Search vanilla `gui` files for draggable value controls (for example in game settings or character creation) and read their definitions plus the `.info` and data-type dumps for the property names. [Verify such controls exist and are usable from mods]
2. Prototype a test window where dragging changes a GUI-local value.
3. Solve the hard part: **getting an arbitrary number from the GUI into a script effect.** A scripted GUI `Execute` call takes scopes, not obvious numeric arguments. Candidate solutions: pass the value through an added scope or a variable the GUI can write, or quantize the slider into discrete positions that each call a fixed effect.
4. Adopt the slider only if the value reaches the effect without hacks likely to break on patches. Otherwise ship +/- buttons and presets (already planned). This is a polish item, not a blocker.

### 3.8 Logic design in detail

**Data model**

- `var:dlc_delta` (int) on the target character. Absent means 0.
- Ladder modifier keys in `common/modifiers`: `dlc_dl_p1, p2, p4, p8, p16, p32, p64` and `dlc_dl_n1, n2, n4, n8, n16, n32`, each carrying one `domain_limit` value. Modifier needs two localization lines (name and description), per the usual character-modifier pattern.
- Added with `add_character_modifier` with no duration (permanent) and removed with `remove_character_modifier`. Confirm exact keys in the `script_docs` dump.

**Scripted effects** (all prefixed `dlc_`)

| Effect | Behavior |
| --- | --- |
| `dlc_apply_delta` | Remove every ladder modifier, then add the modifiers whose bits sum to `dlc_delta` |
| `dlc_set_delta` | Clamp the requested value to range, store it, call `dlc_apply_delta` |
| `dlc_change_delta` | Add a step to the current delta, then `dlc_set_delta` |
| `dlc_reset` | Remove ladder modifiers and clear the variable |
| `dlc_reset_all` | Reset every living character (used before uninstalling; fire once, never on a pulse) |
| `dlc_inherit_on_succession` | Copy the delta to the new ruler when the `dlc_inheritance` rule allows |

Decomposition pseudocode (illustrative, not final syntax):

```
remaining = abs(dlc_delta)
for bit in [64, 32, 16, 8, 4, 2, 1]:
    if remaining >= bit:
        add_modifier(sign + bit)
        remaining -= bit
```

Because this is greedy over powers of two, any integer in range gets a unique minimal set. The effect is idempotent, so reapplying it is always safe.

**Event-driven only.** No monthly or yearly pulse in v1. Recompute only when the user changes the value or on a succession hook. This keeps the mod cheap and avoids load on large saves.

**Natural limit in absolute-target mode.** To let the user type a target, compute `natural = effective - current delta`. This needs a readable effective limit in script or GUI [Verify via dumps]. If it isn't readable, v1 is delta-only and the target mode moves to a later release.

**Access checks.** The interaction's `is_shown`/`is_valid` and each scripted GUI's `is_valid` enforce the `dlc_access` rule.

**Hooks.** Succession and game-start behavior use `on_action` entries written as **appends** (never redefining a vanilla on_action's trigger or effect). Find the right succession on_action names in vanilla `common/on_action`. [Verify]

### 3.9 AI integration: investigation plan

The claim "vanilla AI sees the changed limit" is the part most worth proving early.

1. Search the game directory for `domain_limit` and for the over-limit loc keys to list every script that reads or caps the limit (AI scripts, script values, interactions, over-limit penalties).
2. For each hit, note whether it reads the computed stat (responds to our modifier) or a hardcoded number (does not). Record in `docs/ai-notes.md`.
3. Confirm the AI actually acts on the limit in practice with the protocol in section 6.4.
4. Optional later feature: a game rule that applies a domain-limit modifier to all AI rulers, using the same game-rule-plus-modifier pattern seen in a Paradox forum answer, kept separate from per-character edits.

### 3.10 Compatibility plan

- Additive only: own window, `dlc_` prefix, no vanilla file overrides in v1.
- Never edit `window_character.gui` in the base mod. Offer a separate compatibility module for overhaul mods if demand exists.
- Document load-order advice and known conflict classes: UI overhauls, mods hardcoding domain limits, total conversions with custom governments.
- Run ck3-tiger with each popular overhaul loaded as a parent mod to catch conflicts (tiger can load parent mods first).

---

## 4. Repository layout

```
ck3-domain-limit-control/
├── README.md                     # user-facing: what, install, screenshots, known issues
├── SPEC.md                       # this document
├── CHANGELOG.md
├── LICENSE                       # choose before first release (e.g. MIT or a CC license)
├── .gitignore
├── mod/                          # exactly what gets shipped/uploaded
│   ├── descriptor.mod            # name, version, supported_version, tags
│   ├── .metadata/metadata.json   # launcher metadata [Verify current format]
│   ├── thumbnail.png
│   ├── common/
│   │   ├── modifiers/            # the ladder modifiers
│   │   ├── scripted_effects/     # dlc_apply_delta, dlc_reset_*
│   │   ├── scripted_triggers/
│   │   ├── character_interactions/
│   │   ├── game_rules/
│   │   └── on_action/            # note: singular folder name
│   ├── events/
│   ├── gui/
│   │   ├── dlc_window.gui
│   │   └── scripted_widgets/
│   └── localization/english/
├── tests/
│   ├── static/                   # repo-local structure/script checks
│   ├── runtime/                  # manual + semi-automated test saves and checklists
│   └── ai/                       # AI behavior test protocol and recorded results
├── tools/
│   ├── check_structure.py        # no game files required
│   ├── check_steam_build.sh      # build-id probe
│   └── package.sh                # zip mod/ for releases
└── .github/
    ├── workflows/
    ├── ISSUE_TEMPLATE/
    └── known_build.txt           # last game build id the mod was verified against
```

Hard rule: **never commit vanilla game files** (not even for convenience in CI). See section 8.

---

## 5. Implementation plan

### Milestone 0: groundwork (1-2 days)

- Create repo, license, README, empty mod skeleton that loads cleanly in the launcher.
- Set up the toolchain: VS Code with a CK3 script language extension and `ck3-tiger` running locally. Several extensions exist (a language server and a toolkit extension that wraps ck3-tiger, adds an error.log watcher and can launch the game in debug mode).
- Pin the game version you develop against; record it in `known_build.txt`.
- Ground truth first: run the `script_docs` and `DumpDataTypes` dumps from the console on the pinned build and commit nothing from them (they derive from game files). Use them as the reference for effect, trigger and data-function names.
- Search vanilla files for `domain_limit` and the over-limit loc keys (section 3.9) and write `docs/ai-notes.md`.

### Milestone 1: engine proof (1-2 days)

- Implement 3-4 ladder modifiers by hand and apply them with console commands to confirm the effective domain limit changes and vanilla penalties/UI respond.
- Test against the pitfalls in section 2 (conquerors, nomads and the other strict governments in section 2.1, over-limit tooltips).
- **Go/no-go gate:** if the effective limit does not behave, stop and redesign before building UI.

### Milestone 2: scripted core (2-3 days)

- Full ladder, `dlc_apply_delta`, `dlc_set_delta`, `dlc_change_delta`, clamping, `dlc_reset` and `dlc_reset_all` (section 3.8).
- Unit-style tests via console/event scripts that set a delta and assert the resulting limit.

### Milestone 3: UI phase 1 (3-5 days)

- **3a:** interaction plus event-driven menu (Layer 1) with +/- controls and readout. Ship-worthy on its own.
- **3b:** scripted widget window (Layer 2): resolve how to open it, wire scripted GUI buttons, add live readouts.
- **3c:** slider spike (section 3.7), time-boxed; adopt only if it passes the gate.
- Localization, icons, tooltips.

### Milestone 4: game rules and inheritance (1-2 days)

- `dlc_access`, `dlc_inheritance`, on_action succession hook, reset-all interaction.

### Milestone 5: AI verification (ongoing, 2-3 days)

- Run the AI test protocol (section 6.3), record results in `tests/ai/`.

### Milestone 6: release 0.1.0

- README with screenshots and a Known Issues section, changelog, tagged release, first distribution (section 7).

### Milestone 7: stretch

- True slider if feasible, absolute-lock mode, optional duchy/vassal limit controls, compatibility patches for popular UI and total-conversion mods.

### Known behaviors to document in the README

- Edited games: users should keep a backup save before first use.
- Cheat-style mods are generally understood to disable achievements. [Verify for this mod's exact content]
- Compatibility: mods that replace the character interaction UI or hardcode limits may conflict.

---

## 6. Testing and verification

### 6.1 Static checks (automated, no game needed)

Run locally and in CI on every push:

- `descriptor.mod` present with name, version and `supported_version`.
- Folder-name traps: `common/on_action` (singular), `localization` (American spelling).
- Localization files: `l_english:` header matches filename, UTF-8 with BOM as required, no tabs.
- No vanilla file overrides unless explicitly allow-listed (prefer additive scripting).
- Identifier prefix check: all new keys start with `dlc_`.

### 6.2 Semantic validation with `ck3-tiger` (needs vanilla files)

`ck3-tiger` is a validator that reads vanilla files plus your mod and reports problems such as missing localization or a trigger used in the wrong scope. It supports a baseline mode (`--json` to snapshot, `--suppress baseline.json` to show only new reports) and a `ck3-tiger.conf` file in the mod directory for filtering. Treat any new tiger warning as a failing check; maintain a reviewed baseline for accepted false positives. Pin the tiger release version in CI for reproducibility and bump it deliberately, because new tiger versions track game updates and may add checks.

### 6.3 Runtime tests (in the game)

Maintain a committed set of test saves (small, no copyrighted content beyond what a save contains; **verify saves do not embed anything you can't publish**) and a checklist:

| # | Test | Pass criteria |
| --- | --- | --- |
| R1 | Apply +N / -N to the player | Effective limit equals natural + delta in the UI and tooltips |
| R2 | Apply to an AI vassal | Same, and the window shows correct values for non-player characters |
| R3 | Reset | All ladder modifiers removed, delta cleared |
| R4 | Save, reload | Overrides persist |
| R5 | Succession with inheritance off / on | Matches the game rule |
| R6 | Natural limit changes (new perk, title, trait) | Effective limit tracks it in delta mode |
| R7 | Clamp boundaries | Values beyond range are clamped, no errors |
| R8 | Nomad, conqueror, tribal and clan rulers | No hard-cap surprises, or documented if present |
| R9 | Over-limit state | Vanilla penalties apply and tooltips read sensibly |
| R10 | Mod removal after use | Save loads; documented cleanup works |
| R11 | Other UI mods enabled | Window opens and works with a UI overhaul mod loaded |
| R12 | error.log after a play session | No new errors attributable to the mod |
| R13 | Event menu: repeated clicks | Readout refreshes each time, no stuck or duplicated events |
| R14 | Widget: open, close, reopen, switch target | Readouts match the selected character, no GUI errors in the log |
| R15 | Rapid repeated changes (for example 50 changes in a row) | Exactly the expected ladder modifiers remain, none orphaned |
| R16 | Strict-limit governments (nomadic, Mandala and similar) | Modifier works as intended, or the UI shows a clear warning |
| R17 | Tooltips | The override appears as a named line in the domain-limit tooltip |

### 6.4 AI behavior protocol

The headline claim is "the AI acts on the new limit", so test it explicitly:

1. Start from a fixed test save with a known AI ruler holding more counties than their natural limit allows, and another holding fewer.
2. Run A: lower the first ruler's limit; Run B: raise the second's. Control: change nothing.
3. Fast-forward a fixed period (for example 10 years) with fixed random seed where possible.
4. Record: number of held domain counties over time, vassalization/revocation or grant events, and whether penalty modifiers appear.
5. Pass if changed rulers diverge from the control in the expected direction. Record results in `tests/ai/` along with game build id and mod version. AI behavior is stochastic, so run several seeds or repeats before concluding.

### 6.5 Regression against game updates

On each new game build: run static checks and tiger (automated), then the runtime checklist and AI protocol (manual or semi-automated). Update `known_build.txt` and `supported_version` only after they pass.

---

## 7. Distribution

| Platform | Role | Notes |
| --- | --- | --- |
| **GitHub** (source + Releases) | Source of truth, versioned zips, issue tracker | Release zip contains the `mod/` folder contents |
| **Steam Workshop** | Primary player-facing channel | Largest CK3 mod audience; auto-updates for subscribers |
| **Nexus Mods** | Secondary | CK3 has a presence there; manual or API upload [Verify upload options] |
| Paradox's own mod hosting via the launcher | Possible | I did not verify its current upload workflow or rules [Verify] |

Recommendation: ship GitHub Releases first, then publish to the Steam Workshop once 0.1.0 passes the full test matrix. Add Nexus later if there is demand.

Publishing checklist:

- Thumbnail, short description, and a **Known issues / compatibility** section.
- Tags: gameplay, cheat/utility as appropriate.
- Link back to the GitHub repo for bug reports.
- Keep `supported_version` current; outdated mods show warnings in the launcher.

Workshop upload from CI is possible but needs care (section 8.4), so the first upload should be manual.

---

## 8. CI/CD

### 8.1 Feasibility verdict

| Capability | Feasible? | Notes |
| --- | --- | --- |
| Static structure/loc checks | Yes, fully on GitHub-hosted runners | No game files needed |
| `ck3-tiger` validation | Yes, but needs vanilla files | Cannot live in a public repo; see 8.2 |
| Detect a new game build | Yes | SteamCMD `app_info_print`, scheduled workflow |
| Auto-open an issue or PR on a new build | Yes | Standard GitHub Actions |
| Release packaging | Yes | Zip `mod/`, attach to a GitHub Release |
| Steam Workshop upload from CI | Possible with caveats | Steam Guard, credential secrets, preview/tags limits |
| Fully automated in-game runtime tests | Not realistically | The game is GUI-based; no headless harness was found. Keep runtime tests manual or semi-automated |

### 8.2 The key constraint: game files in a public repo

The maintainer of a published tiger GitHub Action explains that the action is deliberately left incomplete because publishing game files in a public repository would amount to piracy, so each user has to set it up themselves, with the game files kept out of the public repo. ck3-tiger's own documentation also notes that you need to set up the action yourself because of copyright. This spec follows that line:

- The public repo contains **no** vanilla files.
- Options for giving tiger access to vanilla files, in order of preference:

**Option A (recommended): self-hosted runner on your own machine with CK3 installed.**
Vanilla files never leave your computer. Run the heavy jobs (tiger, update-watch follow-up) there.
*Security caution:* a self-hosted runner attached to a public repo can execute code from pull requests. Restrict it: run self-hosted jobs only on pushes to protected branches and on manually dispatched workflows, require approval for workflows from outside contributors, and never run fork PRs on it.

**Option B: a private companion repository holding the validation setup and game files**, with a token in secrets for checkout, as the published tiger action's guide describes. This is what that action's author recommends, but the licensing question is yours to judge; I can't give legal advice, so read the game's license terms before doing it.

**Option C: download the game in CI via SteamCMD with an account that owns it.** Technically possible but puts account credentials in CI, is slow (large download every run unless cached), and may conflict with Steam's terms. Not recommended. [Verify whether anonymous login can fetch CK3; likely not, since it is a paid game.]

GitHub-hosted runners can still run the static checks (8.3, workflow 1) with no game files, which gives contributors fast feedback on every PR.

### 8.3 Workflows

**Workflow 1: `static.yml`** (GitHub-hosted; on push and PR)

```yaml
name: static
on: [push, pull_request]
jobs:
  structure:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: python3 tools/check_structure.py mod/
```

**Workflow 2: `validate.yml`** (self-hosted runner; push to main and manual dispatch only)

```yaml
name: validate
on:
  push:
    branches: [main]
  workflow_dispatch:
jobs:
  tiger:
    runs-on: [self-hosted, windows, ck3]
    steps:
      - uses: actions/checkout@v4
      - name: ck3-tiger with baseline
        shell: pwsh
        run: |
          # Paths and tiger version pinned in repo variables.
          & $env:TIGER_PATH --suppress tests/static/tiger-baseline.json mod/descriptor.mod
```

Fail the job on any report not in the baseline. [Verify the exit-code behavior of the pinned tiger version so the job fails properly.]

**Workflow 3: `watch-game-update.yml`** (scheduled; detects a new build)

Approach (a community pattern for Steam games): run SteamCMD anonymously, print app info for App ID 1158310, extract the build id for the `public` branch, and compare to `.github/known_build.txt`. Several server-management projects use `+login anonymous +app_info_print <appid>` for this and note you may need to refresh the app info cache first (`+app_info_update 1`) to get a current value. SteamDB is an alternative source and is itself built on the same app-info data.

```yaml
name: watch-game-update
on:
  schedule:
    - cron: "17 */6 * * *"     # every 6 hours
  workflow_dispatch:
jobs:
  probe:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install steamcmd
        run: |
          sudo add-apt-repository -y multiverse
          sudo dpkg --add-architecture i386
          sudo apt-get update
          echo steamcmd steam/question select "I AGREE" | sudo debconf-set-selections
          sudo apt-get install -y steamcmd
      - name: Read current public build id
        id: build
        run: bash tools/check_steam_build.sh 1158310 public >> "$GITHUB_OUTPUT"
      - name: Compare with last verified build
        id: cmp
        run: |
          known=$(cat .github/known_build.txt)
          echo "changed=$([ "$known" != "${{ steps.build.outputs.buildid }}" ] && echo true || echo false)" >> "$GITHUB_OUTPUT"
      - name: Open an issue when the game updated
        if: steps.cmp.outputs.changed == 'true'
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.create({
              ...context.repo,
              title: `Game build changed: ${{ steps.build.outputs.buildid }}`,
              body: "Re-run validation and the runtime checklist, then update known_build.txt and supported_version.",
              labels: ["game-update"]
            });
```

Notes:
- The installation commands above are illustrative; adjust to the runner image. A community action (setup-steamcmd) exists that sets up SteamCMD in a workflow and could replace the manual install. [Verify current usage]
- Avoid creating duplicate issues: have the workflow check for an open `game-update` issue for the same build id first.
- Scheduled workflows in public repos are paused after a period of repository inactivity; keep the repo active or re-enable them. [Verify current GitHub policy]
- The probe needs no game files and no credentials, so it can run on GitHub-hosted runners safely.

When the probe detects a change, a human (or a `workflow_dispatch` chain to the self-hosted runner) runs workflow 2, then the manual runtime checklist. Optionally the workflow can open a PR that bumps `supported_version` in `descriptor.mod` once tiger passes, but a maintainer should merge it only after the runtime checks.

**Workflow 4: `release.yml`** (on tag `v*`)

```yaml
name: release
on:
  push:
    tags: ["v*"]
jobs:
  package:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bash tools/package.sh "${GITHUB_REF_NAME}"
      - uses: softprops/action-gh-release@v2
        with:
          files: dist/*.zip
```

### 8.4 Optional: Steam Workshop publishing from CI

Several GitHub Actions exist for uploading Workshop items: one with built-in Steam Guard 2FA code generation, one that sets up SteamCMD and uploads builds or Workshop items using a stored login-config secret. Concerns:

- Credentials: use a dedicated Steam account if possible, store secrets in an Actions **environment** with required reviewers so uploads need manual approval.
- Steam Guard: the usual approach is to complete the MFA login once locally and store the resulting SteamCMD config (base64) as a secret, as one deploy action documents. Treat this secret as a password.
- SteamCMD limitations: one example project notes SteamCMD can't set Workshop tags, so metadata may need to be set on the Workshop page manually.
- A VDF file describing the Workshop item (content folder, preview image, title, description, changelog) is required by SteamCMD's `workshop_build_item` flow. [Verify exact fields in Valve's documentation]
- CK3 mods are typically uploaded through the launcher's own tooling; check whether SteamCMD-uploaded items appear and behave correctly in the launcher before automating. [Verify]

Recommendation: do the first Workshop upload by hand, confirm it works, and only then consider automating updates with a manually approved workflow.

### 8.5 Update-response procedure

1. `watch-game-update` opens a `game-update` issue.
2. Run `validate.yml` on the self-hosted runner against the new build. Fix new tiger reports.
3. Run runtime checklist R1-R12 and the AI protocol (at least a smoke subset) on the new build.
4. If all pass: bump `known_build.txt`, `supported_version`, `CHANGELOG.md`; tag a release; publish.
5. If something breaks: label the issue `breaking`, post a Workshop notice that the mod may be unstable on the new version, fix, repeat.

---

## 9. Risks and open questions

| Risk / question | Mitigation / next step |
| --- | --- |
| Hard caps or special rules override modifier-based limits for some rulers | Milestone 1 gate; document exceptions |
| Slider widget not available to mods, or no way to pass an arbitrary number from GUI to script | Ship button UI; slider is a stretch goal gated by the spike in 3.7 |
| Domain-limit rules changed in 1.19 and a DLC patch may land around 2026-11-17 | Run Milestone 0 against the newest build; keep the delta design; re-verify section 2.1 numbers from game files |
| Natural or effective limit not readable from script | Delta-only v1; compute limit in GUI or defer absolute-target mode |
| No clean way to open a scripted widget on demand | Layer 1 event menu is the shipping fallback |
| GUI-to-script binding syntax changes between patches | Keep GUI thin; rely on tiger/GUI checks and the update procedure |
| Orphaned modifiers if the mod is removed | Reset-all interaction; document uninstall steps |
| Game updates change domain-limit internals | Automated build watch plus manual regression |
| Other mods override domain limit | Compatibility notes; test with the most popular overhauls |
| Duchy/vassal limits let AI hoard in other ways | Non-goal for v1; evaluate a v2 companion control |
| Legal/ToS: game files and Steam credentials in CI | Self-hosted runner, no game files in the repo, approval-gated secrets; read the relevant terms yourself |
| Self-hosted runner security on a public repo | Restrict triggers, require approval for outside contributors, no fork PRs |
| Multiplayer desync | Declare unsupported until tested |
| Exact `descriptor.mod` / `.metadata` fields, Workshop VDF fields | Check the current wiki/Valve docs when implementing |

---

## 10. References

- Paradox Dev Diary #87 (scripted widgets, modifiers improvements): https://www.paradoxinteractive.com/zh-CN/games/crusader-kings-iii/news/dev-diary-87-royal-modding
- Forum thread showing `domain_limit` as a modifier applied through a game rule: https://admin-forum.paradoxplaza.com/forum/threads/triggered-modifiers.1418256/latest
- Forum thread about modding functions and domain-limit loc keys: https://admin-forum.paradoxplaza.com/forum/threads/are-there-api-docs.1636929
- ck3-tiger (validator, baseline, GitHub Action note): https://docs.rs/crate/ck3-tiger/1.16.0 and https://docs.rs/crate/tiger-lib/latest
- Tiger GitHub Action explanation of the game-files/piracy constraint: https://awesome.ecosyste.ms/projects/github.com%2Fkaiser-chris%2Ftiger-action-public
- CK3 modding toolkit (VS Code, tiger integration, error.log watcher): https://github.com/JDeffner/ck3-modding-toolkit/wiki/Editor-Features
- Paradox modding language server extension: https://marketplace.visualstudio.com/items?itemName=unlomtrois.pdxl
- CK3 modding wiki mirror (Markdown): https://www.pkgstats.com/pkg:ck3-modding-wiki
- Steam Workshop upload action with Steam Guard support: https://github.com/weilbyte/steam-workshop-upload
- Upload-to-Steam action (builds and Workshop items): https://awesome.ecosyste.ms/projects/github.com%2Fbuildalon%2Fupload-steam
- Steam deploy action describing the one-time MFA/config approach: https://github.com/Pugstorm/steam-deploy
- Workshop deploy via Docker noting SteamCMD tag limitation: https://github.com/gmod-wikugim/gmod-workshop-deploy-docker
- SteamCMD build-id probing patterns: https://github.com/cryptton2004/7dtd-server/blob/master/update_check.sh and https://steamcommunity.com/app/346110/discussions/0/535152511358957700/
- SteamDB FAQ (app info via SteamKit and `app_info_print`): https://steamdb.info/faq
- "Virtually Infinite Domain Fix" comments (pitfalls): https://steamcommunity.com/sharedfiles/filedetails/comments/3337637913
- Dev Diary #126 (data model slicing, datacontext, plugin widgets): https://forum.paradoxplaza.com/forum/threads/dev-diary-126-modding-activities.1580680/
- ck3-tiger source for scripted GUI call validation: https://docs.rs/crate/tiger-lib/1.19.0/source/src/data/scripted_guis.rs and https://docs.rs/crate/tiger-lib/latest/source/src/data/scripted_guis.rs
- Domain limit after patch 1.19 (2026 guide): https://after-strategy.com/en/ck3-how-to-increase-domain-limit-2026/
- Domain limit basics and over-limit penalties (older guides): https://gamerempire.net/?p=34430 and https://www.fandomspot.com/ck3-going-over-domain-limit/
- Game-rule plus modifier pattern for domain limit (forum): https://admin-forum.paradoxplaza.com/forum/threads/triggered-modifiers.1418256/latest
- Reading a script variable in GUI, plus event/on_action examples (forum): https://forum.paradoxplaza.com/forum/threads/modding-quick-questions-and-answers.1414681/post-27125618
- Character modifier and on_action basics (forum): https://forum.paradoxplaza.com/forum/threads/modding-quick-questions-and-answers.1414681/page-93
- Paradox Modding Toolkit (GUI widget tree, layout preview, visual editor, script_docs and data-type dumps): https://github.com/JDeffner/paradox-modding-toolkit/wiki/Feature-Overview and https://github.com/JDeffner/paradox-modding-toolkit/wiki/Supported-Games
- Divine Intervention Cheat Menu changelog (single tabbed editor window, templates): https://steamcommunity.com/sharedfiles/filedetails/changelog/2986538297?p=4
- Customizable GUI hub mod (module approach to avoid window_character.gui conflicts): https://catalogue.smods.ru/archives/104245

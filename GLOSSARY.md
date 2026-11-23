# Glossary

Terms are used with these exact meanings in `SPEC.md`, issues, PRs and code comments.

| Term | Meaning |
| --- | --- |
| **Domain limit** | The number of holdings a ruler may personally hold without vanilla penalties. The engine statistic this mod edits. |
| **Natural limit** | The limit the game would compute with no Domainwright override: title tier, perks, innovations, tenets and government rules. |
| **Effective limit** | Natural limit plus the override: what the player sees and the AI acts on. |
| **Delta** | The override, stored per character in `var:dlc_delta`. Signed integer, clamped to `-63 … +127`. Absent means zero. |
| **Ladder** | The fixed set of `domain_limit` character modifiers — one per power of two — used to express any delta. |
| **Bit modifier** | A single rung of the ladder, e.g. `dlc_domain_limit_p8` (`+8`). |
| **Apply** | `dlc_apply_delta`: strip every rung, then add back the rungs summing to the delta. Idempotent. |
| **Reset** | Clear the delta and strip the ladder from one character (`dlc_reset`) or every character (`dlc_reset_all`). |
| **Strict government** | A government whose own rules constrain the limit — nomadic, Mandala, Wanua, Ritsuryo, Soryo — where `domain_limit_max` or a scripted rule may beat the ladder. |
| **Grace period** | Vanilla's one-year window in which newly acquired over-limit holdings cause no penalties and produce no income. Interacts with the `domain_size_excluding_grace_period` script value. |
| **Layer 1** | The event-driven menu: a character interaction opens `dlc_menu.0001`, options apply the delta and re-fire the event. Ships first. |
| **Layer 2** | The scripted widget window plus scripted GUIs. An upgrade over Layer 1, not a dependency of it. |
| **Layer 3** | Optional integrations, e.g. a readout in the vanilla character window, shipped separately so the base mod never overrides `window_character.gui`. |
| **Scripted widget** | A `.gui` window registered in `gui/scripted_widgets`, so the engine creates it without a code reference. |
| **Scripted GUI** | A `common/scripted_guis` entry with `scope`, `is_shown`, `is_valid` and `effect`, called from `.gui` with `GetScriptedGui('key').Execute( GuiScope.SetRoot( Character.MakeScope ).End )`. |
| **On_action** | A hook the engine fires (`on_death`, `on_title_gain`, `on_game_start`, yearly pulses). Folder is `common/on_action`, singular. |
| **Append rule** | Never redefine a vanilla on_action, effect, trigger or game rule. Add a new `dlc_`-prefixed one, or add to an existing on_action's event list only if the file is additive. |
| **`dlc_` prefix** | The namespace for every identifier this mod creates. It is short for *domain limit control*, not "downloadable content". |
| **Override** | Shipping a file at a vanilla path. Forbidden in v1; the mod is additive only. |
| **Tiger** | `ck3-tiger`, the community validator. Needs vanilla files, so it runs on a self-hosted runner. |
| **Build id** | Steam's identifier for a game build, probed with `app_info_print` so the repo notices patches. |
| **Go/no-go gate** | Milestone 1's stop point: if the effective limit does not respond to the ladder in game, the design is reconsidered before any UI work. |

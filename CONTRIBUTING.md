# Contributing to Domainwright

Thanks for helping. This is a small mod with a strict rule set, so the fastest way to get a change merged is to
follow the rules below exactly.

## The hard rule: no vanilla game files

**Never commit, attach or paste vanilla Crusader Kings III files** — not scripts, not localization, not
`descriptor.mod` examples from the game, not `script_docs` or `DumpDataTypes` output. They are copyrighted and
their presence in a public repo is a piracy problem. This is why the semantic validator (ck3-tiger) runs on a
self-hosted runner and why `docs/` cites game files by path and line number instead of quoting them at length.

If a bug report needs a game file to explain itself, describe the path and the relevant lines in prose.

## Before you open a PR

```bash
python3 tools/check_structure.py mod/
```

That is the same check CI runs on every push, and it must pass. It covers:

- `descriptor.mod` and `.metadata/metadata.json` present and internally consistent;
- the folder-name traps (`common/on_action` singular, `localization` American spelling);
- UTF-8 **with BOM** and a matching `l_english:` header in every localization file, no tabs;
- every new top-level key prefixed `dlc_`;
- no vanilla-file overrides.

If you have CK3 installed and `ck3-tiger`, run it too:

```bash
ck3-tiger --suppress tests/static/tiger-baseline.json mod/descriptor.mod
```

New warnings are failures. Accepted false positives go into the baseline in a separate PR with a comment
explaining why.

## Branches, commits and PRs

- Branch from `main` as `feat/<slug>`, `fix/<slug>`, `docs/<slug>` or `chore/<slug>`.
- One concern per commit; write the *why*, not the *what*.
- PRs use the template's three sections: **Summary**, **Evidence**, **Merge Danger**. Evidence means a real
  command output, a screenshot from the game, or a test-save observation — not "should work".
- Link the issue the PR closes (`Closes #12`).

## Changing the mod's scripting

- **Additive only.** Do not edit vanilla files. Do not redefine a vanilla on_action, scripted effect, scripted
  trigger, game rule or modifier; append your own `dlc_`-prefixed entry instead.
- Every identifier — modifiers, effects, triggers, interactions, game rules, events, loc keys, variables —
  starts with `dlc_`. Variables additionally carry the `dlc_` prefix, e.g. `dlc_delta`.
- Folder is `common/on_action` (singular). Localization is `localization` (American spelling).
- Localization keys are quoted and colon-numbered (`dlc_thing:0 "Thing"`), and the file must keep its BOM.
- Keep the ladder in `common/modifiers/` and the decomposition in `dlc_apply_delta`; do not hand-apply bits
  anywhere else, or the "exactly one modifier set" invariant breaks.

## Reporting a bug

Use the bug report issue form. Include:

- game version and mod version;
- the character (title, government) you edited and the delta you set;
- what the tooltip said versus what you expected;
- `Documents/Paradox Interactive/Crusader Kings III/logs/error.log` lines that name a `dlc_` identifier —
  paste those lines only, not the whole log.

Screenshots of the domain-limit tooltip are the single most useful attachment.

## Testing claims

Behaviour claims need evidence. If you cannot test in game, say so and mark the claim `[Verify]` in the PR, the
way `SPEC.md` does. A merged PR with an untested claim is fine; a merged PR that hides one is not.

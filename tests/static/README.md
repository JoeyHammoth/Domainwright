# Static tests

`tools/check_structure.py` is the whole no-game-required suite, and CI runs it on every push. It checks the
traps documented in `docs/modding-notes.md`: the singular `common/on_action`, the American `localization`, the
UTF-8 BOM, the `dlc_` prefix, and vanilla-file overrides.

`tiger-baseline.json` is the reviewed ck3-tiger baseline used by `validate.yml`. It starts empty, which means
"every tiger report is new and therefore a failure". Add an entry only with a comment in the PR explaining why
the report is a false positive, and expect to remove it when tiger or the game is updated.

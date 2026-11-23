#!/usr/bin/env python3
"""Static checks for the Domainwright mod. Requires no game files.

Usage:
    python3 tools/check_structure.py [mod_dir]

Exit code 0 means every check passed. Errors fail the build; warnings are printed
but do not fail it (CI treats warnings as advisory).
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

PREFIX = "dlc_"

# Directories a CK3 mod may ship. Anything else is probably a mistake.
ALLOWED_TOP_LEVEL = {
    "common",
    "events",
    "gui",
    "localization",
    "gfx",
    "history",
    "sound",
    "music",
    "interface",
    "dlc",
}

# Vanilla GUI files this mod must never override (SPEC 3.6 / 3.10).
FORBIDDEN_OVERRIDES = {
    "gui/window_character.gui",
    "gui/hud.gui",
    "gui/interaction_menu_window.gui",
}

# Top-level keys that are not ours: the engine's own declaration forms, plus the
# vanilla on_action hooks this mod deliberately extends. Extending a hook is additive
# and is the only way to react to a vanilla event; adding to this set needs a comment
# in the PR explaining why no dlc_-prefixed key can do the job.
ALLOWED_TOP_LEVEL_KEYS = {
    "namespace",
    "on_title_gain_inheritance",
    "on_death",
}

KEY_RE = re.compile(r'^\s*([A-Za-z0-9_.\-]+)\s*=\s*\{')
LOC_RE = re.compile(r'^\s*([A-Za-z0-9_.\-]+)\s*:\s*\d*\s*"(.*)"\s*$')


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, message: str) -> None:
        self.errors.append(message)

    def warn(self, message: str) -> None:
        self.warnings.append(message)

    def show(self) -> int:
        for message in self.warnings:
            print(f"warning: {message}")
        for message in self.errors:
            print(f"error: {message}")
        if self.errors:
            print(f"\nFAILED: {len(self.errors)} error(s), {len(self.warnings)} warning(s)")
            return 1
        print(f"OK: 0 errors, {len(self.warnings)} warning(s)")
        return 0


def read_text(path: Path, report: Report) -> str:
    try:
        return path.read_text(encoding="utf-8-sig")
    except UnicodeDecodeError:
        report.error(f"{path}: not valid UTF-8")
        return ""


def check_descriptor(mod: Path, report: Report) -> None:
    descriptor = mod / "descriptor.mod"
    if not descriptor.is_file():
        report.error("mod/descriptor.mod is missing")
        return
    text = read_text(descriptor, report)
    for field in ("name", "version", "supported_version"):
        if not re.search(rf'^\s*{field}\s*=\s*"', text, re.MULTILINE):
            report.error(f"descriptor.mod: missing quoted '{field}' field")
    version = re.search(r'^\s*supported_version\s*=\s*"([^"]+)"', text, re.MULTILINE)
    if version and not re.fullmatch(r"\d+\.\d+\.\*|\d+\.\d+\.\d+(\.\d+)?", version.group(1)):
        report.error(f"descriptor.mod: unsupported supported_version '{version.group(1)}'")
    if "path=" in text or "path =" in text:
        report.warn("descriptor.mod sets 'path='; only needed outside the user mod directory")


def check_metadata(mod: Path, report: Report) -> None:
    metadata = mod / ".metadata" / "metadata.json"
    if not metadata.is_file():
        report.error("mod/.metadata/metadata.json is missing")
        return
    try:
        data = json.loads(read_text(metadata, report) or "{}")
    except json.JSONDecodeError as exc:
        report.error(f"metadata.json is not valid JSON: {exc}")
        return
    if not data:
        report.error("metadata.json is empty")
        return
    for field in ("name", "version"):
        if field not in data:
            report.error(f"metadata.json: missing '{field}'")


def check_layout(mod: Path, report: Report) -> None:
    if (mod / "localisation").exists():
        report.error("found 'localisation/'; CK3 requires the American spelling 'localization/'")
    if (mod / "common" / "on_actions").exists():
        report.error("found 'common/on_actions/'; the engine only reads 'common/on_action/'")
    for child in sorted(mod.iterdir()):
        if child.name in {".metadata", "descriptor.mod", "thumbnail.png", "README.md"}:
            continue
        if child.name.startswith("."):
            continue
        if child.is_dir() and child.name not in ALLOWED_TOP_LEVEL:
            report.warn(f"unexpected top-level directory '{child.name}'")
    if not (mod / "common").is_dir():
        report.error("mod/common/ is missing")


def check_overrides(mod: Path, report: Report) -> None:
    for rel in sorted(FORBIDDEN_OVERRIDES):
        if (mod / rel).is_file():
            report.error(f"{rel} overrides a vanilla GUI file; use a separate compatibility module")


def script_files(mod: Path) -> list[Path]:
    files: list[Path] = []
    for folder in ("common", "events"):
        root = mod / folder
        if root.is_dir():
            files.extend(p for p in root.rglob("*.txt") if p.is_file())
    return files


def check_prefix(mod: Path, report: Report) -> None:
    """Every top-level definition the mod creates must be namespaced.

    Only depth 0 is checked: script bodies are full of engine keywords (if, limit,
    option, is_valid, ...) that are not ours to rename. Brace counting is naive on
    purpose - a ``#`` comment containing a brace is rare and would only shift the
    reported line, not hide an unnamespaced definition.
    """
    for path in script_files(mod):
        rel = path.relative_to(mod).as_posix()
        depth = 0
        for number, line in enumerate(read_text(path, report).splitlines(), start=1):
            stripped = line.strip()
            if not stripped.startswith("#"):
                match = KEY_RE.match(line)
                if match and depth == 0:
                    key = match.group(1)
                    if key not in ALLOWED_TOP_LEVEL_KEYS and not key.startswith(PREFIX):
                        report.error(f"{rel}:{number}: top-level key '{key}' does not start with '{PREFIX}'")
            depth += line.count("{") - line.count("}")
            if depth < 0:
                report.error(f"{rel}:{number}: unbalanced closing brace")
                depth = 0


def check_events(mod: Path, report: Report) -> None:
    events_dir = mod / "events"
    if not events_dir.is_dir():
        return
    for path in sorted(events_dir.rglob("*.txt")):
        rel = path.relative_to(mod).as_posix()
        text = read_text(path, report)
        namespace = re.search(r"^\s*namespace\s*=\s*(\S+)", text, re.MULTILINE)
        if not namespace:
            report.error(f"{rel}: no 'namespace =' declaration")
            continue
        ns = namespace.group(1)
        if not ns.startswith(PREFIX):
            report.error(f"{rel}: namespace '{ns}' does not start with '{PREFIX}'")
        for event_id in re.findall(r"^\s*(" + re.escape(ns) + r"\.\d+)\s*=\s*\{", text, re.MULTILINE):
            if event_id.count(".") != 1:
                report.error(f"{rel}: suspicious event id '{event_id}'")


def check_localization(mod: Path, report: Report) -> None:
    loc_root = mod / "localization"
    if not loc_root.is_dir():
        report.error("mod/localization/ is missing")
        return
    loc_keys: dict[str, str] = {}
    for path in sorted(loc_root.rglob("*.yml")):
        rel = path.relative_to(mod).as_posix()
        raw = path.read_bytes()
        if not raw.startswith(b"\xef\xbb\xbf"):
            report.error(f"{rel}: missing UTF-8 BOM (first key will be swallowed)")
        text = raw.decode("utf-8-sig", errors="replace")
        lines = text.splitlines()
        if not lines:
            report.error(f"{rel}: empty file")
            continue
        header = lines[0].strip()
        if not re.fullmatch(r"l_[a-z]+:", header):
            report.error(f"{rel}: first line must be a language header such as 'l_english:'")
        expected = re.search(r"_l_([a-z]+)\.yml$", path.name)
        if expected and header != f"l_{expected.group(1)}:":
            report.error(f"{rel}: header '{header}' does not match filename language")
        for number, line in enumerate(lines[1:], start=2):
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if "\t" in line:
                report.error(f"{rel}:{number}: tab character in localization (use spaces)")
            match = LOC_RE.match(line)
            if not match:
                report.warn(f"{rel}:{number}: could not parse localization line")
                continue
            key = match.group(1)
            if key in loc_keys:
                report.error(f"{rel}:{number}: duplicate key '{key}' (also in {loc_keys[key]})")
            loc_keys[key] = rel
            if not key.startswith(("dlc", "rule_dlc_", "setting_dlc_")):
                report.error(f"{rel}:{number}: key '{key}' is not namespaced")

    # Modifier keys must be localized, or tooltips display raw keys.
    modifier_files = list((mod / "common" / "modifiers").glob("*.txt")) if (mod / "common" / "modifiers").is_dir() else []
    for path in modifier_files:
        for key in re.findall(r"^\s*(" + PREFIX + r"[A-Za-z0-9_]+)\s*=\s*\{", read_text(path, report), re.MULTILINE):
            if key not in loc_keys:
                report.error(f"{path.name}: modifier '{key}' has no localization entry")

    # Event option names and interaction names must exist.
    for path in sorted((mod / "events").rglob("*.txt")) if (mod / "events").is_dir() else []:
        text = read_text(path, report)
        for number, line in enumerate(text.splitlines(), start=1):
            match = re.match(r"\s*(name|title|desc)\s*=\s*([A-Za-z0-9_.]+)\s*$", line)
            if match and not match.group(2).startswith("["):
                key = match.group(2)
                if key not in loc_keys:
                    report.error(f"{path.name}:{number}: '{key}' has no localization entry")


def check_encoding(mod: Path, report: Report) -> None:
    for path in script_files(mod):
        raw = path.read_bytes()
        if b"\r\n" in raw:
            report.warn(f"{path.relative_to(mod).as_posix()}: contains CRLF line endings")
        if raw.startswith(b"\xef\xbb\xbf"):
            report.warn(f"{path.relative_to(mod).as_posix()}: starts with a BOM (not expected in script files)")


def main() -> int:
    mod = Path(sys.argv[1] if len(sys.argv) > 1 else "mod")
    report = Report()
    if not mod.is_dir():
        print(f"error: '{mod}' is not a directory")
        return 1
    check_descriptor(mod, report)
    check_metadata(mod, report)
    check_layout(mod, report)
    check_overrides(mod, report)
    check_prefix(mod, report)
    check_events(mod, report)
    check_localization(mod, report)
    check_encoding(mod, report)
    return report.show()


if __name__ == "__main__":
    sys.exit(main())

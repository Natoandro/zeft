#!/usr/bin/env python3
"""Bump package versions in the configured repository files."""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys


def log(message: str) -> None:
    print(f"[bump-version] {message}", file=sys.stderr)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Update package versions in the configured repository files."
    )
    levels = parser.add_mutually_exclusive_group()
    levels.add_argument("--major", dest="level", action="store_const", const="major")
    levels.add_argument("--minor", dest="level", action="store_const", const="minor")
    levels.add_argument("--patch", dest="level", action="store_const", const="patch")
    args = parser.parse_args()
    level = args.level or "patch"

    try:
        repo_root = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, OSError) as error:
        log(f"ERROR: could not locate repository root: {error}")
        return 1

    root = Path(repo_root)
    config_path = root / "scripts" / "version_files.json"
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        log(f"ERROR: could not read version file configuration: {error}")
        return 1

    if not isinstance(config, list) or not config:
        log("ERROR: version file configuration must be a non-empty list.")
        return 1

    entries_by_file = {}
    for entry in config:
        try:
            relative_path = Path(entry["file"])
            if relative_path.is_absolute() or ".." in relative_path.parts:
                raise ValueError("file path must stay within the repository")
            pattern = re.compile(entry["regex"])
            is_base = entry.get("base", False)
        except (AttributeError, KeyError, TypeError, ValueError, re.error) as error:
            log(f"ERROR: invalid version file configuration entry: {error}")
            return 1
        entries_by_file.setdefault(relative_path, []).append((pattern, is_base))

    prepared = []
    base_version = None
    base_count = 0
    for relative_path, file_entries in entries_by_file.items():
        path = root / relative_path
        log(f"Reading {relative_path}.")
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as error:
            log(f"ERROR: could not read {relative_path}: {error}")
            return 1

        spans = []
        for pattern, is_base in file_entries:
            matches = list(pattern.finditer(text))
            if len(matches) != 1 or "version" not in pattern.groupindex:
                log(f"ERROR: expected one version match in {relative_path}.")
                return 1

            match = matches[0]
            spans.append(match.span("version"))
            if is_base:
                base_count += 1
                base_version = match.group("version")
        prepared.append((path, relative_path, text, spans))

    if base_count != 1 or base_version is None:
        log("ERROR: version file configuration must mark exactly one base file.")
        return 1

    major, minor, patch = map(int, base_version.split("."))
    current_version = f"{major}.{minor}.{patch}"
    log(f"Current version: {current_version}; applying {level} bump.")
    if level == "major":
        major, minor, patch = major + 1, 0, 0
    elif level == "minor":
        minor, patch = minor + 1, 0
    else:
        patch += 1

    version = f"{major}.{minor}.{patch}"
    originals = []
    for path, relative_path, text, spans in prepared:
        updated = text
        for start, end in sorted(spans, reverse=True):
            updated = updated[:start] + version + updated[end:]
        try:
            path.write_text(updated, encoding="utf-8")
        except OSError as error:
            log(f"ERROR: could not write {relative_path}: {error}")
            restore_files(originals)
            return 1
        originals.append((path, text))
        log(f"Updated {relative_path}.")

    log("Updating the uv workspace lockfile.")
    try:
        lock_result = subprocess.run(
            ["uv", "lock"], cwd=root, stdout=sys.stderr, check=False
        )
    except OSError as error:
        log(f"ERROR: could not run uv lock: {error}")
        restore_files(originals)
        return 1
    if lock_result.returncode != 0:
        log(f"ERROR: uv lock failed (exit {lock_result.returncode}).")
        restore_files(originals)
        return 1

    log(f"Updated package version: {current_version} -> {version}.")
    print(version)
    return 0


def restore_files(files: list[tuple[Path, str]]) -> None:
    for path, text in reversed(files):
        try:
            path.write_text(text, encoding="utf-8")
        except OSError as error:
            log(f"ERROR: could not restore {path}: {error}")


if __name__ == "__main__":
    sys.exit(main())

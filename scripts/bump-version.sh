#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[bump-version] %s\n' "$*" >&2
}

trap 'status=$?; printf "[bump-version] ERROR: command failed (exit %s, line %s): %s\n" \
  "$status" "$LINENO" "$BASH_COMMAND" >&2; exit "$status"' ERR

log "Parsing bump level."
if [[ "$#" -gt 1 ]]; then
  log "ERROR: usage: scripts/bump-version.sh [major|minor|patch]"
  exit 2
fi

level="${1:-patch}"
if [[ "$level" != major && "$level" != minor && "$level" != patch ]]; then
  log "ERROR: usage: scripts/bump-version.sh [major|minor|patch]"
  exit 2
fi
log "Selected bump level: $level"

log "Locating repository root."
repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
log "Repository root: $repo_root"
log "Updating version in build.zig.zon."

python3 - "$level" <<'PY'
from pathlib import Path
import re
import sys


def log(message: str) -> None:
    print(f"[bump-version] {message}", file=sys.stderr)


manifest = Path("build.zig.zon")
log(f"Reading {manifest}.")
try:
    text = manifest.read_text(encoding="utf-8")
except OSError as error:
    log(f"ERROR: could not read {manifest}: {error}")
    raise SystemExit(1) from error
pattern = re.compile(
    r'^([ \t]*\.version[ \t]*=[ \t]*")([0-9]+)\.([0-9]+)\.([0-9]+)("[ \t]*,?[ \t]*)$',
    re.M,
)
matches = list(pattern.finditer(text))
if len(matches) != 1:
    log("ERROR: expected one stable semantic version in build.zig.zon.")
    raise SystemExit(1)

match = matches[0]
major, minor, patch = map(int, match.group(2, 3, 4))
current_version = f"{major}.{minor}.{patch}"
level = sys.argv[1]
log(f"Current version: {current_version}; applying {level} bump.")
if level == "major":
    major, minor, patch = major + 1, 0, 0
elif level == "minor":
    minor, patch = minor + 1, 0
else:
    patch += 1

version = f"{major}.{minor}.{patch}"
updated = text[:match.start()] + match.group(1) + version + match.group(5) + text[match.end():]
try:
    manifest.write_text(updated, encoding="utf-8")
except OSError as error:
    log(f"ERROR: could not write {manifest}: {error}")
    raise SystemExit(1) from error
log(f"Updated package version: {current_version} -> {version}.")
print(version)
PY

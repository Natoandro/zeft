#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -gt 1 ]]; then
  echo "Usage: scripts/bump-version.sh [major|minor|patch]" >&2
  exit 2
fi

level="${1:-patch}"
if [[ "$level" != major && "$level" != minor && "$level" != patch ]]; then
  echo "Usage: scripts/bump-version.sh [major|minor|patch]" >&2
  exit 2
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

python3 - "$level" <<'PY'
from pathlib import Path
import re
import sys

manifest = Path("build.zig.zon")
text = manifest.read_text(encoding="utf-8")
pattern = re.compile(
    r'^([ \t]*\.version[ \t]*=[ \t]*")([0-9]+)\.([0-9]+)\.([0-9]+)("[ \t]*,?[ \t]*)$',
    re.M,
)
matches = list(pattern.finditer(text))
if len(matches) != 1:
    raise SystemExit("Expected one stable semantic version in build.zig.zon.")

match = matches[0]
major, minor, patch = map(int, match.group(2, 3, 4))
level = sys.argv[1]
if level == "major":
    major, minor, patch = major + 1, 0, 0
elif level == "minor":
    minor, patch = minor + 1, 0
else:
    patch += 1

version = f"{major}.{minor}.{patch}"
updated = text[:match.start()] + match.group(1) + version + match.group(5) + text[match.end():]
manifest.write_text(updated, encoding="utf-8")
print(version)
PY

"""Run the repository's release tagging workflow."""

from pathlib import Path
import subprocess
import sys


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    script = repo_root / "scripts" / "tag-release.sh"
    try:
        result = subprocess.run(
            ["bash", str(script), *sys.argv[1:]],
            cwd=repo_root,
            check=False,
        )
    except OSError as error:
        print(f"[tag-release] ERROR: could not run release script: {error}", file=sys.stderr)
        return 1
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())

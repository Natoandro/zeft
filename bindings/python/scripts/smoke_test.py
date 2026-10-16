"""Import the installed Zeft distribution and render a small template."""

from __future__ import annotations

import subprocess
import sys


def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] not in {"ok", "sdist"}:
        raise SystemExit("usage: smoke_test.py <ok|sdist>")
    value = sys.argv[1]
    expected = f"<p>{value}</p>"
    source = (
        "import zeft; "
        "assert zeft._native.build_mode == 'ReleaseSafe'; "
        "template = zeft.compile('<p>{{ name }}</p>'); "
        f"assert template.render({{'name': '{value}'}}) == '{expected}'; "
        "template.close()"
    )
    subprocess.run([sys.executable, "-I", "-c", source], check=True)


if __name__ == "__main__":
    main()

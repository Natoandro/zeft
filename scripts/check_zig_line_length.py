#!/usr/bin/env python3
"""Reject staged Zig source lines longer than 100 characters."""

import subprocess
import sys

LIMIT = 100


def log(message: str) -> None:
    print(f"[check-zig-line-length] {message}", file=sys.stderr)


def code_length(line: str) -> int:
    """Count line characters outside Zig string literals and comments."""
    if line.lstrip().startswith("\\\\"):
        return 0  # Zig multiline string content.

    length = 0
    in_string = False
    escaped = False
    index = 0

    while index < len(line):
        char = line[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue

        if char == "/" and index + 1 < len(line) and line[index + 1] == "/":
            return length + len(line) - index
        if char == '"':
            in_string = True
        else:
            length += 1
        index += 1

    return length


def main() -> int:
    log("Reading staged Zig file list from Git.")
    try:
        staged = subprocess.run(
            ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR", "--", "*.zig"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
    except (subprocess.CalledProcessError, OSError) as error:
        return_code = getattr(error, "returncode", "unavailable")
        log(f"ERROR: could not list staged Zig files (exit {return_code}).")
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            print(error.stderr.rstrip(), file=sys.stderr)
        return 1
    violations = []
    log(f"Found {len(staged)} staged Zig file(s).")

    for path in staged:
        log(f"Checking {path}.")
        try:
            content = subprocess.run(
                ["git", "show", f":{path}"], check=True, capture_output=True
            ).stdout.decode("utf-8", errors="replace")
        except (subprocess.CalledProcessError, OSError) as error:
            return_code = getattr(error, "returncode", "unavailable")
            log(f"ERROR: could not read staged file {path} (exit {return_code}).")
            if isinstance(error, subprocess.CalledProcessError) and error.stderr:
                print(error.stderr.decode("utf-8", errors="replace").rstrip(), file=sys.stderr)
            return 1
        for number, line in enumerate(content.splitlines(), start=1):
            if len(line) > LIMIT and code_length(line) > LIMIT:
                violations.append((path, number, len(line)))

    if violations:
        log(f"Found {len(violations)} line length violation(s).")
        for path, number, length in violations:
            print(f"{path}:{number}: {length} characters (limit {LIMIT})", file=sys.stderr)
        print("Split long Zig lines before committing.", file=sys.stderr)
        return 1

    log("All staged Zig files pass the line length check.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

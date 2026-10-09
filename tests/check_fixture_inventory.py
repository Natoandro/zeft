#!/usr/bin/env python3
"""Check the statically declared integration fixture inventory.

This checks literal Zig imports, descriptor arrays, harness ID arrays, and
expectGolden calls in the repository's fixture convention. It cannot prove
that control flow executes every descriptor; zig build test verifies behavior.
Run from any directory: python3 tests/check_fixture_inventory.py
"""
from __future__ import annotations

import argparse
import ast
from collections import Counter
from pathlib import Path
import re
import sys


# Metadata strings use ordinary Zig literals. Skip comments before examining
# code so examples and commented registrations cannot count as active metadata.
TOKEN = re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|[A-Za-z_][A-Za-z_0-9]*|[^\s]', re.S)


def tokens(source: str) -> list[str]:
    return [token for token in TOKEN.findall(source) if not token.startswith(("//", "/*"))]


def literal(token: str) -> str | None:
    if not token.startswith('"'):
        return None
    return ast.literal_eval(token)


def invocations(code: list[str], name: str):
    for i in range(len(code) - 3):
        if code[i:i + 3] == ["@", name, "("] and literal(code[i + 3]) is not None:
            yield literal(code[i + 3])


def array_body(code: list[str], start: int) -> list[str]:
    opening = code.index("{", start)
    depth = 1
    for i in range(opening + 1, len(code)):
        if code[i] == "{":
            depth += 1
        elif code[i] == "}":
            depth -= 1
            if depth == 0:
                return code[opening + 1:i]
    raise ValueError("unterminated fixture registry")


def records(body: list[str]):
    depth = 0
    start = 0
    for i, token in enumerate(body):
        if token == "{":
            if depth == 0:
                start = i
            depth += 1
        elif token == "}":
            depth -= 1
            if depth == 0:
                yield body[start:i + 1]


def fields(record: list[str]) -> dict[str, str]:
    result = {}
    for i in range(len(record) - 3):
        if record[i] == "." and record[i + 2] == "=":
            value = literal(record[i + 3])
            if value is not None:
                result[record[i + 1]] = value
    return result


def check(root: Path) -> list[str]:
    tests = root / "tests"
    entry = tests / "integration.zig"
    errors: list[str] = []
    reachable: dict[Path, list[str]] = {}

    def visit(path: Path):
        if path in reachable:
            return
        if not path.is_file():
            errors.append(f"missing imported module: {path.relative_to(root)}")
            return
        code = tokens(path.read_text())
        reachable[path] = code
        for imported in invocations(code, "import"):
            if imported.endswith(".zig"):
                visit((path.parent / imported).resolve())

    visit(entry.resolve())
    for module in sorted(tests.glob("e2e_*.zig")):
        if module.resolve() not in reachable:
            errors.append(f"inactive fixture module: {module.relative_to(root)}")

    referenced: set[Path] = set()
    ids: list[str] = []
    counts: Counter[str] = Counter()

    def fixture_file(module: Path, path: str):
        file = (module.parent / path).resolve()
        if file.suffix not in (".tmpl", ".out"):
            errors.append(f"unexpected fixture extension: {path}")
        if not file.is_relative_to((tests / "fixtures").resolve()):
            errors.append(f"fixture outside tests/fixtures: {path}")
        referenced.add(file)
        if not file.is_file():
            errors.append(f"missing referenced fixture: {path}")
        return file

    for module, code in reachable.items():
        for embedded in invocations(code, "embedFile"):
            if Path(embedded).suffix in (".tmpl", ".out"):
                fixture_file(module, embedded)
        for i in range(len(code) - 4):
            if code[i:i + 2] != ["pub", "const"]:
                continue
            name = code[i + 2]
            if not (name.endswith("_cases") or name == "harness_ids"):
                continue
            body = array_body(code, i + 4)
            if name == "harness_ids":
                registry_ids = [literal(token) for token in body if literal(token) is not None]
                ids.extend(registry_ids)
                counts[module.name] += len(registry_ids)
                continue
            for record in records(body):
                metadata = fields(record)
                if "id" not in metadata or "path" not in metadata:
                    errors.append(f"unrecognized descriptor in {module.name}:{name}")
                    continue
                ids.append(metadata["id"])
                counts[module.name] += 1
                embedded = list(invocations(record, "embedFile"))
                fixture_file(module, metadata["path"])
                if not embedded or embedded[0] != metadata["path"]:
                    errors.append(f"{metadata['id']}: source path disagrees with embedding")
                if "expected_path" in metadata:
                    fixture_file(module, metadata["expected_path"])
                    if len(embedded) != 2 or embedded[1] != metadata["expected_path"]:
                        errors.append(f"{metadata['id']}: expected_path disagrees with embedding")
                elif "expected" in record:
                    errors.append(f"{metadata['id']}: success descriptor lacks expected_path")
        if module == entry.resolve():
            for i in range(len(code) - 8):
                if code[i:i + 2] != ["expectGolden", "("]:
                    continue
                args = code[i + 2:i + 7:2]
                if len(args) == 3 and all(literal(token) is not None for token in args):
                    case_id, source, expected = map(literal, args)
                    ids.append(case_id)
                    counts["legacy goldens"] += 1
                    fixture_file(module, source)
                    fixture_file(module, expected)

    for case_id, count in Counter(ids).items():
        if count != 1:
            errors.append(f"duplicate execution ID: {case_id} ({count} registrations)")
    actual = {path.resolve() for path in (tests / "fixtures").rglob("*") if path.suffix in (".tmpl", ".out")}
    for orphan in sorted(actual - referenced):
        errors.append(f"orphan fixture: {orphan.relative_to(root)}")
    for name, count in sorted(counts.items()):
        print(f"{name}: {count} named executions")
    print(f"Total: {len(ids)} named executions; {sum(path.suffix == '.tmpl' for path in actual)} template files; {sum(path.suffix == '.out' for path in actual)} output files")
    print("Static inventory only; run zig build test to verify execution and behavior.")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    try:
        errors = check(args.root.resolve())
    except (OSError, ValueError, SyntaxError) as error:
        print(f"Inventory check failed: {error}", file=sys.stderr)
        return 1
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    return bool(errors)


if __name__ == "__main__":
    sys.exit(main())

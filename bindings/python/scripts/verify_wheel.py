"""Check that the built wheel has the expected interpreter and platform tags."""

from __future__ import annotations

import os
import sys
import zipfile
from pathlib import Path


def main() -> None:
    wheels = list(Path("bindings/python/dist").glob("*.whl"))
    if len(wheels) != 1:
        raise SystemExit(f"expected one wheel, found {len(wheels)}")

    expected_python = f"cp{sys.version_info.major}{sys.version_info.minor}"
    expected_platform = f"{os.environ['ZEFT_WHEEL_PLATFORM']}_"
    expected_arch = f"_{os.environ['ZEFT_WHEEL_ARCH']}"

    with zipfile.ZipFile(wheels[0]) as wheel:
        metadata = next(
            name for name in wheel.namelist() if name.endswith(".dist-info/WHEEL")
        )
        tags = [
            line.removeprefix("Tag: ")
            for line in wheel.read(metadata).decode().splitlines()
            if line.startswith("Tag: ")
        ]

    if not tags:
        raise SystemExit(f"wheel has no WHEEL tags: {wheels[0]}")
    for tag in tags:
        python_tag, abi_tag, platform_tag = tag.split("-")
        if python_tag != expected_python:
            raise SystemExit(f"unexpected Python tag {tag}")
        if abi_tag != expected_python:
            raise SystemExit(f"unexpected ABI tag {tag}")
        if not platform_tag.startswith(expected_platform):
            raise SystemExit(f"unexpected platform tag {tag}")
        if not platform_tag.endswith(expected_arch):
            raise SystemExit(f"unexpected architecture tag {tag}")

    print(f"Verified {wheels[0].name}: {', '.join(tags)}")


if __name__ == "__main__":
    main()

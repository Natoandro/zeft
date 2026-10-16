from __future__ import annotations

import os
import shutil
import subprocess
import sys
import sysconfig
from pathlib import Path

from hatchling.builders.hooks.plugin.interface import BuildHookInterface


class ZeftBuildHook(BuildHookInterface):
    """Build the Zig CPython extension when producing a wheel."""

    def initialize(self, version: str, build_data: dict[str, object]) -> None:
        project = Path(self.root).resolve()
        engine = project / "engine"
        if self.target_name == "sdist" and not (engine / "build.zig").exists():
            self._include_engine_sources(project, build_data)
            return
        if self.target_name != "wheel":
            return

        build_data["pure_python"] = False
        build_data["infer_tag"] = True

        if not (engine / "build.zig").exists():
            engine = project.parents[1]

        include_dir = sysconfig.get_path("include")
        if not include_dir:
            raise RuntimeError("Could not determine the CPython include directory")

        subprocess.run(self._zig_build_command(include_dir), cwd=engine, check=True)

        extension_suffix = sysconfig.get_config_var("EXT_SUFFIX")
        if not extension_suffix:
            raise RuntimeError("Could not determine the CPython extension suffix")
        built_extension = self._built_extension(engine)
        package_dir = project / "src" / "zeft"
        package_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(built_extension, package_dir / f"_native{extension_suffix}")

        package_artifact = package_dir / f"_native{extension_suffix}"
        build_data.setdefault("artifacts", []).append(
            str(package_artifact.relative_to(project))
        )

    @staticmethod
    def _zig_build_command(include_dir: str) -> list[str]:
        optimize = os.environ.get("ZEFT_ZIG_OPTIMIZE", "ReleaseSafe")
        if optimize not in {"Debug", "ReleaseSafe", "ReleaseFast", "ReleaseSmall"}:
            raise RuntimeError(
                "ZEFT_ZIG_OPTIMIZE must be Debug, ReleaseSafe, ReleaseFast, or ReleaseSmall"
            )
        command = [
            "zig",
            "build",
            "python-extension",
            f"-Dpython-include={include_dir}",
            f"-Doptimize={optimize}",
        ]
        target = os.environ.get("ZEFT_ZIG_TARGET")
        if target:
            command.append(f"-Dtarget={target}")

        if sys.platform == "win32":
            library = sysconfig.get_config_var("LIBRARY")
            library_dir = sysconfig.get_config_var("LIBDIR") or str(
                Path(sys.base_prefix) / "libs"
            )
            library_path = Path(library) if library else None
            if library_path is None or not library_path.is_file():
                library_dir_path = Path(library_dir)
                candidates = (
                    library_dir_path
                    / f"python{sys.version_info.major}{sys.version_info.minor}.lib",
                    library_dir_path / f"python{sys.version_info.major}.lib",
                )
                library_path = next(
                    (candidate for candidate in candidates if candidate.is_file()),
                    None,
                )
            if library_path is None:
                raise RuntimeError(
                    "Could not find the CPython import library in "
                    f"{library_dir!r} (sysconfig LIBRARY={library!r})"
                )
            command.extend(
                [
                    f"-Dpython-library-dir={library_path.parent}",
                    f"-Dpython-library={library_path.stem}",
                ]
            )
        return command

    @staticmethod
    def _built_extension(engine: Path) -> Path:
        library_dir = engine / "zig-out" / "lib"
        suffix = {
            "win32": ".dll",
            "darwin": ".dylib",
            "linux": ".so",
        }.get(sys.platform)
        if not suffix:
            raise RuntimeError(f"Unsupported platform: {sys.platform}")

        candidates = sorted(library_dir.glob(f"*{suffix}"))
        extension = next(
            (path for path in candidates if path.stem in {"_native", "lib_native"}),
            None,
        )
        if extension is None:
            raise RuntimeError(f"Zig did not produce a CPython library in {library_dir}")
        return extension

    @staticmethod
    def _include_engine_sources(project: Path, build_data: dict[str, object]) -> None:
        repository = project.parents[1]
        files = [repository / "build.zig", repository / "build.zig.zon"]
        files.extend(
            path
            for directory in ("src", "tests", "bench")
            for path in (repository / directory).rglob("*")
            if path.is_file()
        )
        files.extend((repository / "README.md", *project.joinpath("native").glob("*")))

        force_include = build_data.setdefault("force_include", {})
        for source in files:
            if source.parent == project / "native":
                target = Path("engine/bindings/python/native") / source.name
            else:
                target = Path("engine") / source.relative_to(repository)
            force_include[str(source)] = str(target)

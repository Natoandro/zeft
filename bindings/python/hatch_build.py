from __future__ import annotations

import shutil
import subprocess
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

        subprocess.run(
            [
                "zig",
                "build",
                "python-extension",
                f"-Dpython-include={include_dir}",
            ],
            cwd=engine,
            check=True,
        )

        extension_suffix = sysconfig.get_config_var("EXT_SUFFIX")
        if not extension_suffix:
            raise RuntimeError("Could not determine the CPython extension suffix")
        built_extension = engine / "zig-out" / "lib" / "lib_native.so"
        package_dir = project / "src" / "zeft"
        package_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(built_extension, package_dir / f"_native{extension_suffix}")

        package_artifact = package_dir / f"_native{extension_suffix}"
        build_data.setdefault("artifacts", []).append(
            str(package_artifact.relative_to(project))
        )

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

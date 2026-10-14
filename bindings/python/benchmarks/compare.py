"""Compare Zeft, Jinja2, and Mako on equivalent Python rendering workloads.

From ``bindings/python/``, build the Zeft extension with ``uv build --wheel``,
then run ``uv run --with jinja2 --with mako python benchmarks/compare.py``.
uv installs the comparison engines into an ephemeral environment for this run.
Timings are local observations; use the same machine and Python build for
comparisons.
"""

from __future__ import annotations

import argparse
import platform
import statistics
import time
from collections.abc import Callable
from dataclasses import dataclass
from importlib.metadata import PackageNotFoundError, version
from typing import Any

import zeft
from jinja2 import Environment
from mako.template import Template as MakoTemplate


@dataclass
class Engine:
    name: str
    version: str
    compile_template: Callable[[str], Any]
    render: Callable[[Any, dict[str, Any]], str]


@dataclass
class Workload:
    name: str
    context: dict[str, Any]
    expected_fragments: tuple[str, ...]
    sources: dict[str, str]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--iterations", type=int, default=2_000)
    parser.add_argument("--rounds", type=int, default=7)
    parser.add_argument("--items", type=int, default=100)
    args = parser.parse_args()
    if args.iterations < 1 or args.rounds < 1 or args.items < 1:
        parser.error("iterations, rounds, and items must be positive")

    engines = make_engines()
    workloads = make_workloads(args.items)
    print(f"Python {platform.python_version()} | {platform.platform()}")
    print(f"{args.items} items | {args.iterations} iterations x {args.rounds} rounds")
    print("Times are median nanoseconds per operation; output checks run before timing.\n")

    for workload in workloads:
        print(workload.name)
        for engine in engines:
            source = workload.sources[engine.name]
            compiled = engine.compile_template(source)
            rendered = engine.render(compiled, workload.context)
            if not all(fragment in rendered for fragment in workload.expected_fragments):
                raise RuntimeError(f"{engine.name} output check failed for {workload.name}")

            def compile_and_close() -> None:
                candidate = engine.compile_template(source)
                close_candidate = getattr(candidate, "close", None)
                if close_candidate is not None:
                    close_candidate()

            def compile_and_render() -> str:
                candidate = engine.compile_template(source)
                try:
                    return engine.render(candidate, workload.context)
                finally:
                    close_candidate = getattr(candidate, "close", None)
                    if close_candidate is not None:
                        close_candidate()

            compile_ns = measure(
                compile_and_close,
                args.iterations,
                args.rounds,
            )
            render_ns = measure(
                lambda: engine.render(compiled, workload.context),
                args.iterations,
                args.rounds,
            )
            combined_ns = measure(
                compile_and_render,
                args.iterations,
                args.rounds,
            )
            print(
                f"  {engine.name:8} {engine.version:10} "
                f"compile {compile_ns:>10,} ns  render {render_ns:>10,} ns  "
                f"compile+render {combined_ns:>10,} ns"
            )
            close = getattr(compiled, "close", None)
            if close is not None:
                close()
        print()


def make_engines() -> list[Engine]:
    jinja = Environment(autoescape=True)
    return [
        Engine(
            "Zeft",
            _package_version("zeft"),
            lambda source: zeft.compile(source),
            lambda template, context: template.render(context),
        ),
        Engine(
            "Jinja2",
            _package_version("jinja2"),
            lambda source: jinja.from_string(source),
            lambda template, context: template.render(**context),
        ),
        Engine(
            "Mako",
            _package_version("mako"),
            lambda source: MakoTemplate(source, default_filters=["h"]),
            lambda template, context: template.render(**context),
        ),
    ]


def make_workloads(item_count: int) -> list[Workload]:
    zeft_source = (
        "<main><h1>{{ title }}</h1><ul>"
        "{#for item in items}<li>{{ item.name }}: {{ item.description }}</li>{/for}"
        "</ul></main>"
    )
    jinja_source = (
        "<main><h1>{{ title }}</h1><ul>"
        "{% for item in items %}<li>{{ item.name }}: {{ item.description }}</li>{% endfor %}"
        "</ul></main>"
    )
    mako_source = (
        "<main><h1>${title}</h1><ul>\n"
        "% for item in items:\n"
        '<li>${item["name"]}: ${item["description"]}</li>\n'
        "% endfor\n"
        "</ul></main>"
    )
    sources = {"Zeft": zeft_source, "Jinja2": jinja_source, "Mako": mako_source}

    def workload(count: int, name: str) -> Workload:
        items = [
            {"name": f"Item {index}", "description": "Fresh & <local>"}
            for index in range(count)
        ]
        context = {"title": "Today's specials", "items": items}
        fragments = (
            "Item 0",
            "Fresh &amp; &lt;local&gt;",
            "Item " + str(count - 1),
        )
        return Workload(name, context, fragments, sources)

    workloads = [workload(1, "One item")]
    if item_count > 1:
        workloads.append(workload(item_count, f"{item_count} items"))
    return workloads


def measure(operation: Callable[[], Any], iterations: int, rounds: int) -> int:
    for _ in range(min(100, iterations)):
        operation()
    samples = []
    for _ in range(rounds):
        started = time.perf_counter_ns()
        for _ in range(iterations):
            operation()
        samples.append((time.perf_counter_ns() - started) // iterations)
    return int(statistics.median(samples))


def _package_version(name: str) -> str:
    try:
        return version(name)
    except PackageNotFoundError:
        return "source"


if __name__ == "__main__":
    main()

"""Python bindings for the Zeft HTML and XML template engine."""

from __future__ import annotations

from . import _native

__all__ = [
    "TemplateError",
    "CompileError",
    "RenderError",
    "Template",
    "compile",
]


class TemplateError(Exception):
    """Base class for template compilation and rendering errors."""

    def __init__(self, kind: str, span: tuple[int, int] | None) -> None:
        self.kind = kind
        self.span = span
        message = f"{kind.replace('_', ' ')} diagnostic"
        if span is not None:
            message += f" at bytes {span[0]}..{span[1]}"
        super().__init__(message)


class CompileError(TemplateError):
    """Raised when template source cannot be compiled."""


class RenderError(TemplateError):
    """Raised when a compiled template cannot be rendered."""


def _adapt_diagnostic(error: Exception, cls: type[TemplateError]) -> TemplateError:
    kind, start, end = error.args
    span = None if start is None else (start, end)
    return cls(kind, span)


class Template:
    """An owning compiled template."""

    __slots__ = ("_native_template",)

    def __init__(self, native_template: _native.Template) -> None:
        self._native_template: _native.Template | None = native_template

    def render(self, context: object) -> str:
        native_template = self._native_template
        if native_template is None:
            raise ValueError("template is closed")
        try:
            return native_template.render(context)
        except _native.RenderDiagnostic as error:
            raise _adapt_diagnostic(error, RenderError) from None

    def close(self) -> None:
        self._native_template = None

    def __enter__(self) -> Template:
        if self._native_template is None:
            raise ValueError("template is closed")
        return self

    def __exit__(self, exc_type: object, exc: object, traceback: object) -> None:
        self.close()


def compile(
    source: str,
    *,
    format: str = "html",
    whitespace: str = "preserve",
    indentation: str = "  ",
) -> Template:
    """Compile a template and return an owning :class:`Template`."""
    if not isinstance(source, str):
        raise TypeError("source must be str")
    if not isinstance(format, str):
        raise TypeError("format must be str")
    if not isinstance(whitespace, str):
        raise TypeError("whitespace must be str")
    if not isinstance(indentation, str):
        raise TypeError("indentation must be str")
    formats = {"html": 0, "xml": 1}
    whitespace_policies = {"preserve": 0, "compact": 1, "pretty": 2}
    if format not in formats:
        raise ValueError(f"unknown format: {format!r}")
    if whitespace not in whitespace_policies:
        raise ValueError(f"unknown whitespace policy: {whitespace!r}")
    try:
        native_template = _native.compile(
            source, formats[format], whitespace_policies[whitespace], indentation
        )
    except _native.CompileDiagnostic as error:
        raise _adapt_diagnostic(error, CompileError) from None
    return Template(native_template)

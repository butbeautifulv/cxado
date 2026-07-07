from __future__ import annotations

from urllib.parse import urlparse

READONLY_METHODS = frozenset({"GET", "HEAD", "OPTIONS"})


class ReadonlyViolationError(PermissionError):
    """Raised when a mutating DefectDojo API call is blocked in readonly mode."""


def _normalize_path(path: str) -> str:
    if path.startswith("http://") or path.startswith("https://"):
        parsed = urlparse(path)
        return parsed.path or "/"
    return path if path.startswith("/") else f"/{path}"


def assert_readonly_allowed(method: str, path: str, *, readonly: bool) -> None:
    if not readonly:
        return

    verb = method.upper()
    normalized = _normalize_path(path)

    if verb in READONLY_METHODS:
        return

    raise ReadonlyViolationError(
        f"Readonly mode blocks {verb} {normalized}. "
        "Set DEFECTDOJO_READONLY=false to allow mutating API calls."
    )

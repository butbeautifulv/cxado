from __future__ import annotations

from urllib.parse import urlparse

READONLY_METHODS = frozenset({"GET", "HEAD", "OPTIONS"})

# Nessus write endpoints blocked in readonly mode.
WRITE_PATH_PREFIXES = (
    "/scans",
    "/session",
)


class ReadonlyViolationError(PermissionError):
    """Raised when a mutating Nessus API call is blocked in readonly mode."""


def _normalize_path(path: str) -> str:
    if path.startswith("http://") or path.startswith("https://"):
        parsed = urlparse(path)
        return parsed.path or "/"
    return path if path.startswith("/") else f"/{path}"


def _is_write_path(method: str, normalized: str) -> bool:
    verb = method.upper()
    if verb in READONLY_METHODS:
        return False
    if verb == "DELETE" and normalized == "/session":
        return False
    if verb == "POST" and normalized == "/session":
        return False
    if verb == "POST" and normalized.endswith("/export"):
        return False
    if verb in {"POST", "PUT", "PATCH", "DELETE"}:
        if normalized.startswith("/scans") and "/export" in normalized:
            return False
        return True
    return False


def assert_readonly_allowed(method: str, path: str, *, readonly: bool) -> None:
    if not readonly:
        return
    normalized = _normalize_path(path)
    if _is_write_path(method, normalized):
        raise ReadonlyViolationError(
            f"Readonly mode blocks {method.upper()} {normalized}. "
            "Set NESSUS_READONLY=false to allow mutating API calls."
        )

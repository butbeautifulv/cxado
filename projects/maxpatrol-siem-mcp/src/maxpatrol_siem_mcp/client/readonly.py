from __future__ import annotations

from urllib.parse import urlparse

EXACT_POST_PATHS = frozenset(
    {
        "/api/v2/incidents",
        "/api/events/v2/events",
        "/api/events/v2/events/aggregation",
        "/api/assets_temporal_readmodel/v1/assets_grid",
        "/ptms/api/ual/v2/user_actions",
    }
)

PREFIX_POST_PATHS = ("/api/v1/uar/",)

READONLY_METHODS = frozenset({"GET", "HEAD", "OPTIONS"})


class ReadonlyViolationError(PermissionError):
    """Raised when a mutating SIEM API call is blocked in readonly mode."""


def _normalize_path(path: str) -> str:
    if path.startswith("http://") or path.startswith("https://"):
        parsed = urlparse(path)
        return parsed.path or "/"
    return path if path.startswith("/") else f"/{path}"


def _post_allowed(normalized: str) -> bool:
    if normalized in EXACT_POST_PATHS:
        return True
    if normalized.startswith("/api/events/v1/table_lists/") and normalized.endswith("/export"):
        return True
    return any(normalized.startswith(prefix) for prefix in PREFIX_POST_PATHS)


def assert_readonly_allowed(method: str, path: str, *, readonly: bool) -> None:
    if not readonly:
        return

    verb = method.upper()
    normalized = _normalize_path(path)

    if verb in READONLY_METHODS:
        return

    if verb == "POST" and _post_allowed(normalized):
        return

    raise ReadonlyViolationError(
        f"Readonly mode blocks {verb} {normalized}. "
        "Set SIEM_READONLY=false to allow mutating API calls."
    )

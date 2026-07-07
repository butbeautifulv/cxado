import pytest

from maxpatrol_siem_mcp.client.readonly import (
    ReadonlyViolationError,
    assert_readonly_allowed,
)


def test_readonly_allows_get() -> None:
    assert_readonly_allowed("GET", "/api/v2/incidents/abc", readonly=True)
    assert_readonly_allowed("get", "/api/incidentsReadModel/incidents/abc", readonly=True)


def test_readonly_allows_whitelist_post() -> None:
    assert_readonly_allowed("POST", "/api/v2/incidents", readonly=True)
    assert_readonly_allowed("POST", "/api/events/v2/events", readonly=True)
    assert_readonly_allowed("POST", "/api/events/v2/events/aggregation", readonly=True)
    assert_readonly_allowed(
        "POST",
        "/api/assets_temporal_readmodel/v1/assets_grid",
        readonly=True,
    )
    assert_readonly_allowed("POST", "/api/v1/uar/report", readonly=True)
    assert_readonly_allowed(
        "POST",
        "/api/events/v1/table_lists/MyList/export",
        readonly=True,
    )
    assert_readonly_allowed("POST", "/ptms/api/ual/v2/user_actions", readonly=True)


def test_readonly_blocks_delete() -> None:
    with pytest.raises(ReadonlyViolationError):
        assert_readonly_allowed("DELETE", "/api/v2/incidents/abc", readonly=True)


def test_readonly_blocks_put_patch() -> None:
    with pytest.raises(ReadonlyViolationError):
        assert_readonly_allowed("PUT", "/api/v2/incidents/abc", readonly=True)
    with pytest.raises(ReadonlyViolationError):
        assert_readonly_allowed("PATCH", "/api/v2/incidents/abc", readonly=True)


def test_readonly_blocks_post_outside_whitelist() -> None:
    with pytest.raises(ReadonlyViolationError):
        assert_readonly_allowed("POST", "/api/v2/incidents/abc/close", readonly=True)


def test_readonly_disabled_allows_mutations() -> None:
    assert_readonly_allowed("DELETE", "/api/v2/incidents/abc", readonly=False)
    assert_readonly_allowed("POST", "/api/v2/incidents/abc/close", readonly=False)

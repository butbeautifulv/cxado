import pytest

from tenable_mcp.client.readonly import ReadonlyViolationError, assert_readonly_allowed


def test_readonly_blocks_launch() -> None:
    with pytest.raises(ReadonlyViolationError):
        assert_readonly_allowed("POST", "/scans/1/launch", readonly=True)


def test_readonly_allows_export() -> None:
    assert_readonly_allowed("POST", "/scans/1/export", readonly=True)


def test_readonly_allows_get() -> None:
    assert_readonly_allowed("GET", "/scans", readonly=True)

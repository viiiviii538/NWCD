import io
import json
import logging
from unittest.mock import patch

import pytest

import network_map


@pytest.fixture(autouse=True)
def reset_logger():
    """Remove handlers from the network_map logger before and after tests."""
    logger = logging.getLogger("network_map")
    for handler in list(logger.handlers):
        logger.removeHandler(handler)
    yield
    for handler in list(logger.handlers):
        logger.removeHandler(handler)


def test_main_success():
    hosts = [{"ip": "1.2.3.4", "mac": "aa:bb", "vendor": "Vendor"}]
    stdout = io.StringIO()
    stderr = io.StringIO()
    with patch("network_map.discover_hosts", return_value=hosts) as mock_discover, \
         patch("sys.argv", ["network_map.py", "10.0.0.0/24"]), \
         patch("sys.stdout", stdout), \
         patch("sys.stderr", stderr):
        code = network_map.main()

    assert code == 0
    mock_discover.assert_called_once_with("10.0.0.0/24")
    assert stdout.getvalue().strip() == json.dumps({"hosts": hosts}, ensure_ascii=False)
    assert stderr.getvalue() == ""


def test_main_success_without_subnet():
    hosts = [{"ip": "1.2.3.4", "mac": "aa:bb", "vendor": "Vendor"}]
    stdout = io.StringIO()
    stderr = io.StringIO()
    with patch("network_map.discover_hosts", return_value=hosts) as mock_discover, \
         patch("sys.argv", ["network_map.py"]), \
         patch("sys.stdout", stdout), \
         patch("sys.stderr", stderr):
        code = network_map.main()

    assert code == 0
    mock_discover.assert_called_once_with(None)
    assert stdout.getvalue().strip() == json.dumps({"hosts": hosts}, ensure_ascii=False)
    assert stderr.getvalue() == ""


def test_main_failure():
    stdout = io.StringIO()
    stderr = io.StringIO()
    with patch("network_map.discover_hosts", side_effect=RuntimeError("boom")), \
         patch("sys.argv", ["network_map.py"]), \
         patch("sys.stdout", stdout), \
         patch("sys.stderr", stderr):
        code = network_map.main()

    assert code == 1
    assert stdout.getvalue() == ""
    assert stderr.getvalue().strip() == "boom"


def test_configure_logging_routes_output():
    stdout = io.StringIO()
    stderr = io.StringIO()
    with patch("sys.stdout", stdout), patch("sys.stderr", stderr):
        logger = network_map._configure_logging()
        logger.info("hello")
        logger.error("oops")

    assert stdout.getvalue().strip() == "hello"
    assert stderr.getvalue().strip() == "oops"
    assert "oops" not in stdout.getvalue()
    assert "hello" not in stderr.getvalue()


if __name__ == "__main__":  # pragma: no cover - allow running directly
    raise SystemExit(pytest.main([__file__]))


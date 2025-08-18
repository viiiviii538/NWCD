import io
import json
from unittest.mock import patch

import network_map


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
    out_lines = stdout.getvalue().strip().splitlines()
    assert out_lines[0] == json.dumps({"hosts": hosts}, ensure_ascii=False)
    assert out_lines[1] == "Host discovery succeeded"
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
    out_lines = stdout.getvalue().strip().splitlines()
    assert out_lines[0] == json.dumps({"hosts": hosts}, ensure_ascii=False)
    assert out_lines[1] == "Host discovery succeeded"
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
    assert "Host discovery failed: boom" in stderr.getvalue().strip()


if __name__ == "__main__":  # pragma: no cover - allow running directly
    import pytest

    raise SystemExit(pytest.main([__file__]))


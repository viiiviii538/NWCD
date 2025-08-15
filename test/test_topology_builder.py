from subprocess import CompletedProcess
from unittest.mock import patch

import topology_builder


def test_build_paths_traceroute_parsing():
    hosts = [{"ip": "192.168.1.2"}]
    traceroute_output = (
        "traceroute to 192.168.1.2 (192.168.1.2)\n"
        " 1  192.168.1.1  1 ms\n"
        " 2  192.168.1.2  2 ms\n"
    )
    cp = CompletedProcess(args=[], returncode=0, stdout=traceroute_output, stderr="")
    with patch("topology_builder.subprocess.run", return_value=cp):
        data = topology_builder.build_paths(hosts)
    assert data == {"paths": [{"ip": "192.168.1.2", "path": ["LAN", "Router", "Host"]}]}


def test_parse_traceroute_output_extracts_ips():
    output = (
        "traceroute to 8.8.8.8\n"
        " 1  10.0.0.1  1 ms\n"
        " 2  8.8.8.8  2 ms\n"
    )
    hops = topology_builder._parse_traceroute_output(output)
    assert hops == ["10.0.0.1", "8.8.8.8"]


def test_classify_hops_handles_empty_and_multiple():
    assert topology_builder._classify_hops([]) == ["Host"]
    hops = ["10.0.0.1", "8.8.8.8"]
    assert topology_builder._classify_hops(hops) == ["LAN", "Router", "Host"]


def test_build_paths_uses_snmp_augmentation():
    hosts = [{"ip": "192.168.1.2"}]
    with patch("topology_builder.traceroute", return_value=["192.168.1.1", "192.168.1.2"]), \
        patch("topology_builder._augment_with_snmp", return_value=["LAN", "Router", "Host", "SNMP"]) as mock_snmp:
        data = topology_builder.build_paths(hosts, use_snmp=True)
    mock_snmp.assert_called_once()
    assert data == {"paths": [{"ip": "192.168.1.2", "path": ["LAN", "Router", "Host", "SNMP"]}]}


def test_traceroute_uses_windows_command():
    with patch("topology_builder.os.name", "nt"), patch(
        "topology_builder.subprocess.run"
    ) as mock_run:
        mock_run.return_value = CompletedProcess(args=[], returncode=0, stdout="", stderr="")
        topology_builder.traceroute("1.1.1.1")
    mock_run.assert_called_with(
        ["tracert", "-d", "1.1.1.1"], capture_output=True, text=True, timeout=30
    )


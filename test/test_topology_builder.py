import builtins
import sys
import types

import topology_builder


def test_parse_traceroute_output_extracts_ips():
    output = (
        "traceroute to 8.8.8.8\n"
        " 1  10.0.0.1  1 ms\n"
        " 2  8.8.8.8  2 ms\n"
    )
    hops = topology_builder._parse_traceroute_output(output)
    assert hops == ["10.0.0.1", "8.8.8.8"]


def test_build_paths_without_snmp(monkeypatch):
    hosts = [{"ip": "192.168.1.2"}]
    monkeypatch.setattr(
        topology_builder, "traceroute", lambda ip: ["192.168.1.1", "192.168.1.2"]
    )

    original_import = builtins.__import__

    def fake_import(name, *args, **kwargs):
        if name.startswith("pysnmp"):
            raise ImportError
        return original_import(name, *args, **kwargs)

    monkeypatch.setattr(builtins, "__import__", fake_import)

    data = topology_builder.build_paths(hosts, use_snmp=True)
    assert data == {
        "paths": [{"ip": "192.168.1.2", "path": ["LAN", "Router", "Host"]}]
    }


def test_build_paths_with_snmp(monkeypatch):
    hosts = [{"ip": "192.168.1.2"}]
    monkeypatch.setattr(
        topology_builder, "traceroute", lambda ip: ["192.168.1.1", "192.168.1.2"]
    )

    class DummySnmpEngine:
        pass

    hlapi = types.SimpleNamespace(SnmpEngine=DummySnmpEngine)
    monkeypatch.setitem(sys.modules, "pysnmp", types.SimpleNamespace(hlapi=hlapi))
    monkeypatch.setitem(sys.modules, "pysnmp.hlapi", hlapi)

    data = topology_builder.build_paths(hosts, use_snmp=True)
    assert data == {
        "paths": [
            {"ip": "192.168.1.2", "path": ["LAN", "Router", "Host", "SNMP"]}
        ]
    }


#!/usr/bin/env python3
"""Generate network topology graph from scan results."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Iterable, Optional

from graphviz import Graph


def _extract_hosts(data: Any) -> Iterable[dict]:
    """Return iterable of hosts from discover_hosts or lan_port_scan output."""
    if isinstance(data, dict) and "hosts" in data:
        return data.get("hosts", [])
    return data


def build_graph(data: Any, paths_data: Optional[Any] = None) -> Graph:
    """Build a graphviz Graph from parsed scan data.

    Args:
        data: JSON data from ``discover_hosts``/``lan_port_scan`` or similar.
        paths_data: Optional JSON produced by ``topology_builder`` containing a
            ``paths`` array.
    """

    hosts = list(_extract_hosts(data))
    host_map = {}
    for host in hosts:
        ip = host.get("ip") or host.get("device") or "unknown"
        host_map[ip] = host

    paths_by_ip = {}
    if isinstance(paths_data, dict):
        for entry in paths_data.get("paths", []):
            ip = entry.get("ip")
            if not ip:
                continue
            paths_by_ip[ip] = entry.get("path", [])
            if ip not in host_map:
                host = {"ip": ip}
                hosts.append(host)
                host_map[ip] = host

    g = Graph("Network")
    # Use ellipse shapes so that SVG nodes contain <ellipse> elements which can
    # be tapped in the Flutter UI.
    g.attr("node", shape="ellipse")
    g.node("LAN")

    for host in hosts:
        ip = host.get("ip") or host.get("device") or "unknown"
        label_parts = [ip]
        hostname = host.get("hostname")
        if hostname:
            label_parts.append(hostname)
        vendor = host.get("vendor")
        if vendor:
            label_parts.append(vendor)
        label = "\n".join(label_parts)
        g.node(ip, label=label)

        paths = list(host.get("paths", []))
        if ip in paths_by_ip:
            paths.append(paths_by_ip[ip])
        if paths:
            for path in paths:
                prev = None
                for node in path:
                    if node == "Host":
                        break
                    g.node(node)
                    if prev is not None:
                        g.edge(prev, node)
                    prev = node
                if prev is not None:
                    g.edge(prev, ip)
        else:
            g.edge("LAN", ip)
    return g


def save_graph(graph: Graph, output: str) -> None:
    """Save graph to PNG/SVG or DOT depending on extension."""
    path = Path(output)
    if path.suffix.lower() in {".png", ".svg"}:
        fmt = path.suffix.lower()[1:]
        graph.render(path.stem, path.parent, format=fmt, cleanup=True)
    else:
        graph.save(filename=str(path))


def main() -> None:
    parser = argparse.ArgumentParser(description="Create network topology diagram")
    parser.add_argument("input", help="JSON from discover_hosts.py or lan_port_scan.py")
    parser.add_argument(
        "-o", "--output", default="topology.svg", help="Output file (.png/.svg/.dot)"
    )
    parser.add_argument(
        "--paths-json", help="JSON from topology_builder.py containing network paths"
    )
    args = parser.parse_args()

    with open(args.input, "r", encoding="utf-8") as f:
        data = json.load(f)

    paths_data = None
    if args.paths_json:
        with open(args.paths_json, "r", encoding="utf-8") as f:
            paths_data = json.load(f)

    graph = build_graph(data, paths_data)
    save_graph(graph, args.output)
    print(f"Topology written to {args.output}")


if __name__ == "__main__":
    main()

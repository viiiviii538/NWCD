#!/usr/bin/env python3
"""Generate network topology graph from scan results."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Iterable

from graphviz import Graph


def _extract_hosts(data: Any) -> Iterable[dict]:
    """Return iterable of hosts from discover_hosts or lan_port_scan output."""
    if isinstance(data, dict) and "hosts" in data:
        return data.get("hosts", [])
    return data


def build_graph(data: Any) -> Graph:
    """Build a graphviz Graph from parsed scan data."""
    hosts = list(_extract_hosts(data))
    g = Graph("Network")
    # Use ellipse shapes so that SVG nodes contain <ellipse> elements which can
    # be tapped in the Flutter UI.
    g.attr("node", shape="ellipse")
    g.node("LAN")
    for host in hosts:
        ip = host.get("ip") or host.get("device") or "unknown"
        label = ip
        vendor = host.get("vendor")
        if vendor:
            label = f"{ip}\n{vendor}"
        g.node(ip, label=label)
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
    parser.add_argument("-o", "--output", default="topology.svg", help="Output file (.png/.svg/.dot)")
    args = parser.parse_args()

    with open(args.input, "r", encoding="utf-8") as f:
        data = json.load(f)

    graph = build_graph(data)
    save_graph(graph, args.output)
    print(f"Topology written to {args.output}")


if __name__ == "__main__":
    main()

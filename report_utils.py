from typing import Iterable, List

import json
from pathlib import Path

import generate_topology

from common_constants import DANGER_COUNTRIES


def calc_utm_items(score: float, open_ports: Iterable[str], countries: Iterable[str]) -> List[str]:
    """Return which UTM features help mitigate the detected risks.

    Parameters
    ----------
    score : float
        Overall risk score from :func:`calc_risk_score`.
    open_ports : Iterable[str]
        Detected open ports for the host.
    countries : Iterable[str]
        Countries observed in the host's traffic.
    """
    items = set()
    if list(open_ports):
        items.add("firewall")
    if any(str(c).upper() in DANGER_COUNTRIES for c in countries):
        items.add("web_filter")
    if score >= 5:
        items.add("ips")
    return sorted(items)


def generate_topology_diagram(input_path: str, output: str = "topology.svg") -> str:
    """Create a network topology diagram from scan results.

    Parameters
    ----------
    input_path: str
        Path to JSON produced by ``discover_hosts.py`` or ``lan_port_scan.py``.
    output: str
        Output file path. Extension determines format (.png/.svg/.dot).

    Returns
    -------
    str
        The path to the generated diagram.
    """
    with open(input_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    graph = generate_topology.build_graph(data)
    generate_topology.save_graph(graph, output)
    return str(Path(output))


# Allow camelCase name for compatibility with Dart code expectations.
generateTopologyDiagram = generate_topology_diagram


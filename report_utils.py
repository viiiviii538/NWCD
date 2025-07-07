from typing import Iterable, List

from common_constants import DANGER_COUNTRIES


def calc_utm_items(score: int, open_ports: Iterable[str], countries: Iterable[str]) -> List[str]:
    """Return which UTM features help mitigate the detected risks."""
    items = set()
    if list(open_ports):
        items.add("firewall")
    if any(str(c).upper() in DANGER_COUNTRIES for c in countries):
        items.add("web_filter")
    if score >= 5:
        items.add("ips")
    return sorted(items)


#!/usr/bin/env python3
import sys
import json

from security_score import (
    calc_security_score,
    DANGER_PORTS,
    COUNTERMEASURES,
)
from report_utils import calc_utm_items


def parse_args(argv):
    if len(argv) < 7:
        print(
            "Usage: security_report.py <ip> <open_ports_csv> <ssl_status> <spf_valid> <geoip> <utm_active>",
            file=sys.stderr,
        )
        sys.exit(1)
    ip = argv[1]
    ports = [p for p in argv[2].split(',') if p]
    ssl_status = argv[3].lower()
    spf_valid = argv[4].lower() in {"1", "true", "yes"}
    geoip = argv[5]
    utm_active = argv[6].lower() in {"1", "true", "yes"}
    return ip, ports, ssl_status, spf_valid, geoip, utm_active


def calc_score(open_ports, ssl_status, spf_valid, geoip, utm_active=False):
    """Return score, risk descriptions and UTM items."""

    risks = []
    if open_ports:
        risks.append(
            {
                "risk": "Open ports: " + ",".join(open_ports),
                "counter": COUNTERMEASURES.get(
                    "open_ports", "Close unused ports or enable a firewall"
                ),
            }
        )
    if ssl_status in {"invalid", "self-signed"}:
        risks.append(
            {
                "risk": f"SSL certificate {ssl_status}",
                "counter": COUNTERMEASURES.get(
                    "ssl_invalid", "Install a valid SSL certificate"
                ),
            }
        )
    if not spf_valid:
        risks.append(
            {
                "risk": "SPF record missing",
                "counter": COUNTERMEASURES.get(
                    "spf_missing", "Configure an SPF record"
                ),
            }
        )
    if geoip and geoip.upper() != "JP":
        risks.append(
            {
                "risk": f"GeoIP location {geoip}",
                "counter": COUNTERMEASURES.get(
                    "foreign_geoip", "Review foreign traffic or use web filtering"
                ),
            }
        )

    danger_list = [p for p in open_ports if p in DANGER_PORTS]
    data = {
        "danger_ports": danger_list,
        "open_port_count": len(open_ports),
        "geoip": geoip,
        "ssl": ssl_status,
        "dns_fail_rate": 0.0 if spf_valid else 1.0,
        "utm_active": utm_active,
    }

    res = calc_security_score(data)
    score = res["score"]
    utm_items = calc_utm_items(score, open_ports, [geoip])
    return score, risks, utm_items


def main(argv):
    ip, ports, ssl_status, spf_valid, geoip, utm_active = parse_args(argv)
    score, risks, utm_items = calc_score(ports, ssl_status, spf_valid, geoip, utm_active)
    result = {
        "ip": ip,
        "score": score,
        "risks": risks,
        "utmItems": utm_items,

        "open_ports": ports,
        "geoip": geoip,
    }
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main(sys.argv)

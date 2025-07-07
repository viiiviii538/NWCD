#!/usr/bin/env python3
import sys
import json

from risk_score import calc_risk_score
from report_utils import calc_utm_items


def parse_args(argv):
    if len(argv) < 8:
        print(
            "Usage: security_report.py <ip> <open_ports_csv> <ssl_valid> <spf_valid> <dkim_valid> <dmarc_valid> <geoip>",
            file=sys.stderr,
        )
        sys.exit(1)
    ip = argv[1]
    ports = [p for p in argv[2].split(',') if p]
    ssl_valid = argv[3].lower() in {"1", "true", "yes"}
    spf_valid = argv[4].lower() in {"1", "true", "yes"}
    dkim_valid = argv[5].lower() in {"1", "true", "yes"}
    dmarc_valid = argv[6].lower() in {"1", "true", "yes"}
    geoip = argv[7]
    return ip, ports, ssl_valid, spf_valid, dkim_valid, dmarc_valid, geoip




def calc_score(open_ports, ssl_valid, spf_valid, dkim_valid, dmarc_valid, geoip):
    """Compatibility wrapper for CLI usage."""

    risks = []
    if open_ports:
        risks.append(
            {
                "risk": "Open ports: " + ",".join(open_ports),
                "counter": "Close unused ports or enable a firewall",
            }
        )
    if not ssl_valid:
        risks.append(
            {
                "risk": "SSL certificate invalid",
                "counter": "Install a valid SSL certificate",
            }
        )
    if not spf_valid:
        risks.append(
            {
                "risk": "SPF record missing",
                "counter": "Configure an SPF record",
            }
        )
    if not dkim_valid:
        risks.append(
            {
                "risk": "DKIM record missing",
                "counter": "Configure a DKIM record",
            }
        )
    if not dmarc_valid:
        risks.append(
            {
                "risk": "DMARC record missing",
                "counter": "Configure a DMARC policy",
            }
        )
    if geoip and geoip.upper() != "JP":
        risks.append(
            {
                "risk": f"GeoIP location {geoip}",
                "counter": "Review foreign traffic or use web filtering",
            }
        )

    score, _warns = calc_risk_score(open_ports, [geoip] if geoip else [])
    utm_items = calc_utm_items(score, open_ports, [geoip])
    return score, risks, utm_items


def main(argv):
    (
        ip,
        ports,
        ssl_valid,
        spf_valid,
        dkim_valid,
        dmarc_valid,
        geoip,
    ) = parse_args(argv)
    score, risks, utm_items = calc_score(
        ports, ssl_valid, spf_valid, dkim_valid, dmarc_valid, geoip
    )
    result = {
        "ip": ip,
        "score": score,
        "risks": risks,
        "utmItems": utm_items,

        "open_ports": ports,
        "geoip": geoip,
        "dkim_valid": dkim_valid,
        "dmarc_valid": dmarc_valid,
    }
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main(sys.argv)

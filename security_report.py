#!/usr/bin/env python3
import sys
import json


def parse_args(argv):
    if len(argv) < 6:
        print(
            "Usage: security_report.py <ip> <open_ports_csv> <ssl_valid> <spf_valid> <geoip>",
            file=sys.stderr,
        )
        sys.exit(1)
    ip = argv[1]
    ports = [p for p in argv[2].split(',') if p]
    ssl_valid = argv[3].lower() in {"1", "true", "yes"}
    spf_valid = argv[4].lower() in {"1", "true", "yes"}
    geoip = argv[5]
    return ip, ports, ssl_valid, spf_valid, geoip


def calculate_security_score(data: dict) -> float:
    """Return security score (0.0-10.0) from diagnostic result dict."""

    high_risk = 0
    mid_risk = 0
    low_risk = 0

    # High risk factors
    if any(p in [445, 3389, 23] for p in data.get("danger_ports", [])):
        high_risk += 1
    if any(c in ["CN", "RU", "KP"] for c in data.get("geoip", [])):
        high_risk += 1
    if data.get("ssl") in ["invalid", "self-signed"]:
        high_risk += 1
    if data.get("os") in ["Windows 7", "XP", "8"]:
        high_risk += 1

    # Mid risk factors
    if data.get("upnp") is True:
        mid_risk += 1
    if data.get("dns_fail_rate", 0.0) >= 0.5:
        mid_risk += 1
    if data.get("http_ratio", 0.0) >= 0.5:
        mid_risk += 1
    if data.get("unknown_mac_ratio", 0.0) >= 0.2:
        mid_risk += 1
    if data.get("device_count", 0) >= 30:
        mid_risk += 1

    # Low risk factors
    if data.get("open_port_count", 0) >= 10:
        low_risk += 1
    if data.get("intl_traffic_ratio", 0.0) >= 0.5:
        low_risk += 1
    if data.get("spf_dkim") in ["none", "invalid"]:
        low_risk += 1
    if data.get("ip_conflict") is True:
        low_risk += 1

    score = 10.0
    score -= 0.7 * high_risk
    score -= 0.3 * mid_risk
    score -= 0.2 * low_risk

    if data.get("has_utm"):
        score += 1.0
    if data.get("has_mfa"):
        score += 0.3
    if data.get("has_edr"):
        score += 0.2

    return round(max(0.0, min(10.0, score)), 2)


def calc_score(open_ports, ssl_valid, spf_valid, geoip):
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
    if geoip and geoip.upper() != "JP":
        risks.append(
            {
                "risk": f"GeoIP location {geoip}",
                "counter": "Review foreign traffic or use web filtering",
            }
        )

    data = {
        "danger_ports": [int(p) for p in open_ports if p.isdigit()],
        "geoip": [geoip.upper()] if geoip else [],
        "ssl": "valid" if ssl_valid else "invalid",
        "spf_dkim": "valid" if spf_valid else "none",
        "open_port_count": len(open_ports),
    }

    score = calculate_security_score(data)
    utm_items = []
    if score <= 5:
        utm_items = ["firewall", "web_filter", "ips"]
    return score, risks, utm_items


def main(argv):
    ip, ports, ssl_valid, spf_valid, geoip = parse_args(argv)
    score, risks, utm_items = calc_score(ports, ssl_valid, spf_valid, geoip)
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

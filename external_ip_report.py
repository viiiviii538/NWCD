#!/usr/bin/env python3
import argparse
import socket
import ipaddress

try:
    import psutil
except ImportError:
    psutil = None

try:
    import geoip2.database
except ImportError:
    geoip2 = None


RED = "\033[31m"
RESET = "\033[0m"

ENCRYPTED_PORTS = {443, 22, 993, 995, 465, 563, 989, 990}
UNENCRYPTED_PORTS = {80, 20, 21, 23, 25, 110, 143}


def classify_port(port: int) -> str:
    if port in ENCRYPTED_PORTS:
        return "\u6697\u53f7\u5316"  # "暗号化"
    if port in UNENCRYPTED_PORTS:
        return "\u975e\u6697\u53f7\u5316"  # "非暗号化"
    return "\u4e0d\u660e"  # "不明"


def is_private(ip: str) -> bool:
    try:
        return ipaddress.ip_address(ip).is_private
    except ValueError:
        return True


def get_external_connections() -> list[tuple[str, int]]:
    conns = []
    if psutil is None:
        return conns
    for conn in psutil.net_connections(kind="inet"):
        raddr = conn.raddr
        if not raddr:
            continue
        ip = raddr.ip
        port = raddr.port
        if ip and not is_private(ip):
            conns.append((ip, port))
    return conns


def reverse_dns(ip: str) -> str:
    try:
        host, _, _ = socket.gethostbyaddr(ip)
        return host
    except Exception:
        return ""


def geoip_country(reader, ip: str) -> str:
    if reader is None:
        return ""
    try:
        resp = reader.country(ip)
        return resp.country.iso_code or ""
    except Exception:
        return ""


def main():
    parser = argparse.ArgumentParser(description="List external connections with domain and country")
    parser.add_argument(
        "--geoip-db",
        default="GeoLite2-Country.mmdb",
        help="Path to GeoIP2 country database",
    )
    args = parser.parse_args()

    if psutil is None:
        print("psutil module not available")
        return

    reader = None
    if geoip2 is not None:
        try:
            reader = geoip2.database.Reader(args.geoip_db)
        except Exception:
            reader = None

    conns = get_external_connections()
    results = []
    for ip, port in conns:
        domain = reverse_dns(ip)
        country = geoip_country(reader, ip)
        enc_flag = classify_port(port)
        results.append((ip, domain, country, port, enc_flag))

    if reader:
        reader.close()

    for ip, domain, country, port, flag in results:
        domain = domain or "(no PTR)"
        country = country or ""
        line = f"{ip}\t{domain}\t{country}\t{port}\t{flag}"
        if flag == "\u975e\u6697\u53f7\u5316":
            line = f"{RED}{line}{RESET}"
        print(line)


if __name__ == "__main__":
    main()

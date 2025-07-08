#!/usr/bin/env python3
import argparse
import socket
import ipaddress
import json

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
GREEN = "\033[32m"

# Map common ports to protocol names
PORT_PROTOCOLS = {
    20: "FTP",
    21: "FTP",
    22: "SSH",
    23: "Telnet",
    25: "SMTP",
    80: "HTTP",
    110: "POP3",
    143: "IMAP",
    443: "HTTPS",
    465: "SMTPS",
    563: "NNTPS",
    587: "SMTP",
    993: "IMAPS",
    995: "POP3S",
    989: "FTPS",
    990: "FTPS",
}

ENCRYPTED_PORTS = {443, 22, 993, 995, 465, 563, 989, 990}
UNENCRYPTED_PORTS = {80, 20, 21, 23, 25, 110, 143}


def classify_port(port: int) -> str:
    if port in ENCRYPTED_PORTS:
        return "\u6697\u53f7\u5316"  # "暗号化"
    if port in UNENCRYPTED_PORTS:
        return "\u975e\u6697\u53f7\u5316"  # "非暗号化"
    return "\u4e0d\u660e"  # "不明"


def protocol_name(port: int) -> str:
    return PORT_PROTOCOLS.get(port, f"TCP/{port}")


def risk_comment(port: int) -> str:
    if port in UNENCRYPTED_PORTS:
        return "平文通信のため情報漏洩のリスクがあります"
    return ""


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
    parser = argparse.ArgumentParser(
        description="List external connections with encryption status"
    )
    parser.add_argument(
        "--geoip-db",
        default="GeoLite2-Country.mmdb",
        help="Path to GeoIP2 country database",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output JSON instead of colored text",
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

    if args.json:
        data = []
        for ip, domain, country, port, flag in results:
            dest = domain or ip
            proto = protocol_name(port)
            state = "安全" if flag == "\u6697\u53f7\u5316" else "危険" if flag == "\u975e\u6697\u53f7\u5316" else "不明"
            comment = risk_comment(port) if flag == "\u975e\u6697\u53f7\u5316" else ""
            data.append({
                "ip": ip,
                "domain": domain,
                "country": country,
                "dest": dest,
                "protocol": proto,
                "encryption": flag,
                "state": state,
                "comment": comment,
            })
        print(json.dumps(data, ensure_ascii=False))
        return

    print("宛先ドメイン\t通信プロトコル\t暗号化状況\t状態\tコメント")
    for ip, domain, country, port, flag in results:
        dest = domain or ip
        proto = protocol_name(port)
        state = "安全" if flag == "\u6697\u53f7\u5316" else "危険" if flag == "\u975e\u6697\u53f7\u5316" else "不明"
        comment = risk_comment(port) if flag == "\u975e\u6697\u53f7\u5316" else ""
        line = f"{dest}\t{proto}\t{flag}\t{state}\t{comment}"
        if state == "危険":
            line = f"{RED}{line}{RESET}"
        print(line)


if __name__ == "__main__":
    main()

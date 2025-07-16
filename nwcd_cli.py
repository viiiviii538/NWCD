import argparse
import json
from typing import List

from discover_hosts import discover_hosts
from port_scan import run_scan
from lan_port_scan import scan_hosts, DEFAULT_PORTS, _get_subnet
from lan_security_check import run_checks
from security_report import generate_report


def cmd_discover(args: argparse.Namespace) -> None:
    hosts = discover_hosts(args.subnet)
    print(json.dumps({"hosts": hosts}, ensure_ascii=False))


def cmd_port_scan(args: argparse.Namespace) -> None:
    ports = args.port_list.split(",") if args.port_list else None
    scripts = args.script.split(",") if args.script else None
    res = run_scan(
        args.host,
        ports,
        service=args.service,
        os_detect=args.os,
        scripts=scripts,
        timing=args.timing,
    )
    print(
        json.dumps(
            {"host": args.host, "os": res["os"], "ports": res["ports"]},
            ensure_ascii=False,
        )
    )


def cmd_lan_scan(args: argparse.Namespace) -> None:
    subnet = args.subnet or _get_subnet() or "192.168.1.0/24"
    if args.ports:
        ports = [p.strip() for p in args.ports.split(",") if p.strip()]
    else:
        ports = DEFAULT_PORTS
    scripts = args.script.split(",") if args.script else None
    results = scan_hosts(
        subnet,
        ports,
        service=args.service,
        os_detect=args.os,
        scripts=scripts,
        max_workers=args.workers,
    )
    print(json.dumps(results, ensure_ascii=False))


def cmd_lan_check(args: argparse.Namespace) -> None:
    results = run_checks(args.subnet)
    print(json.dumps(results, ensure_ascii=False))


def cmd_security_report(args: argparse.Namespace) -> None:
    ports = [p for p in args.open_ports.split(",") if p]
    res = generate_report(
        args.ip,
        ports,
        args.ssl_status,
        args.spf_valid.lower() in {"1", "true", "yes"},
        args.geoip,
        args.utm_active.lower() in {"1", "true", "yes"},
    )
    print(json.dumps(res, ensure_ascii=False))


def main(argv: List[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="NWCD command line interface")
    sub = parser.add_subparsers(dest="command", required=True)

    p_discover = sub.add_parser("discover-hosts", help="Discover LAN hosts")
    p_discover.add_argument("subnet", nargs="?", help="Target subnet")
    p_discover.set_defaults(func=cmd_discover)

    p_scan = sub.add_parser("port-scan", help="Scan ports on a host")
    p_scan.add_argument("host")
    p_scan.add_argument("port_list", nargs="?", help="Comma separated ports")
    p_scan.add_argument(
        "--service", action="store_true", help="Enable service version detection"
    )
    p_scan.add_argument("--os", action="store_true", help="Enable OS detection")
    p_scan.add_argument("--script", help="Comma separated nmap scripts")
    p_scan.add_argument(
        "--timing", type=int, choices=range(0, 6), help="nmap timing template"
    )
    p_scan.set_defaults(func=cmd_port_scan)

    p_lan = sub.add_parser("lan-scan", help="Discover LAN hosts and scan ports")
    p_lan.add_argument("--subnet")
    p_lan.add_argument("--ports")
    p_lan.add_argument("--service", action="store_true")
    p_lan.add_argument("--os", action="store_true")
    p_lan.add_argument("--script")
    p_lan.add_argument("--workers", type=int)
    p_lan.set_defaults(func=cmd_lan_scan)

    p_check = sub.add_parser("lan-check", help="Run LAN security checks")
    p_check.add_argument("subnet", nargs="?", help="Target subnet")
    p_check.set_defaults(func=cmd_lan_check)

    p_report = sub.add_parser("security-report", help="Generate security report")
    p_report.add_argument("ip")
    p_report.add_argument("open_ports")
    p_report.add_argument("ssl_status")
    p_report.add_argument("spf_valid")
    p_report.add_argument("geoip")
    p_report.add_argument("utm_active")
    p_report.set_defaults(func=cmd_security_report)

    args = parser.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
import json
import sys
import subprocess
import xml.etree.ElementTree as ET
import ipaddress


def run_scan(
    host: str,
    ports: list[str] | None = None,
    service: bool = False,
    os_detect: bool = False,
    scripts: list[str] | None = None,
) -> list[dict[str, str]]:
    cmd = ["nmap"]
    try:
        if ipaddress.ip_address(host).version == 6:
            cmd.append("-6")
    except Exception:
        if ":" in host:
            cmd.append("-6")
    if service:
        cmd.append("-sV")
    if os_detect:
        cmd.append("-O")
    if scripts:
        cmd += ["--script", ",".join(scripts)]
    if not ports:
        cmd += ["-p-", "-oX", "-", host]
    else:
        cmd += ["-p", ",".join(ports), "-oX", "-", host]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip())
    root = ET.fromstring(proc.stdout)
    results = []
    for port in root.findall('.//port'):
        portid = port.get('portid')
        state_elem = port.find('state')
        service_elem = port.find('service')
        state = state_elem.get('state') if state_elem is not None else ''
        service = service_elem.get('name') if service_elem is not None else ''
        item = {'port': portid, 'state': state, 'service': service}
        if service_elem is not None:
            product = service_elem.get('product') or ''
            version = service_elem.get('version') or ''
            extrainfo = service_elem.get('extrainfo') or ''
            if product or version or extrainfo:
                item['service_info'] = ' '.join(
                    [s for s in [product, version, extrainfo] if s]
                ).strip()
        results.append(item)
    return results


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Run nmap port scan")
    parser.add_argument("host", help="Target host")
    parser.add_argument("port_list", nargs="?", help="Comma separated ports")
    parser.add_argument("--service", action="store_true", help="Enable service version detection (-sV)")
    parser.add_argument("--os", action="store_true", help="Enable OS detection (-O)")
    parser.add_argument("--script", help="Comma separated nmap scripts")
    args = parser.parse_args()

    ports = args.port_list.split(',') if args.port_list else []
    scripts = args.script.split(',') if args.script else None
    try:
        res = run_scan(
            args.host,
            ports if ports else None,
            service=args.service,
            os_detect=args.os,
            scripts=scripts,
        )
        print(json.dumps({'host': args.host, 'ports': res}))
    except Exception as e:
        print(json.dumps({'error': str(e)}))
        sys.exit(1)


if __name__ == '__main__':
    main()

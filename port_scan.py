#!/usr/bin/env python3
import json
import sys
import subprocess
import xml.etree.ElementTree as ET


def run_scan(host: str, ports: list[str] | None = None) -> list[dict[str, str]]:
    if not ports:
        cmd = ["nmap", "-p-", "-oX", "-", host]
    else:
        cmd = ["nmap", "-p", ",".join(ports), "-oX", "-", host]
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
        results.append({'port': portid, 'state': state, 'service': service})
    return results


def main():
    if len(sys.argv) < 2:
        print('Usage: port_scan.py <host> [port_list]', file=sys.stderr)
        sys.exit(1)
    host = sys.argv[1]
    ports = sys.argv[2].split(',') if len(sys.argv) >= 3 else []
    try:
        res = run_scan(host, ports if ports else None)
        print(json.dumps({'host': host, 'ports': res}))
    except Exception as e:
        print(json.dumps({'error': str(e)}))
        sys.exit(1)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
import json
import sys
import subprocess
import xml.etree.ElementTree as ET
import ipaddress
import selectors
import time

from network_utils import SCAN_TIMEOUT


def _exec_nmap(cmd: list[str], progress_timeout: float | None) -> str:
    """Run nmap command and return stdout. If progress_timeout is provided,
    terminate the process if no output is received within the timeout."""
    if progress_timeout is None:
        try:
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=SCAN_TIMEOUT)
        except subprocess.TimeoutExpired:
            raise RuntimeError("nmap scan timed out")
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.strip())
        return proc.stdout

    with subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    ) as proc:
        selector = selectors.DefaultSelector()
        selector.register(proc.stdout, selectors.EVENT_READ)
        selector.register(proc.stderr, selectors.EVENT_READ)
        last_update = time.time()
        stdout_parts: list[str] = []
        stderr_parts: list[str] = []
        while True:
            events = selector.select(timeout=1)
            if events:
                for key, _ in events:
                    line = key.fileobj.readline()
                    if not line:
                        continue
                    last_update = time.time()
                    if key.fileobj is proc.stdout:
                        stdout_parts.append(line)
                    else:
                        stderr_parts.append(line)
            else:
                if progress_timeout and time.time() - last_update > progress_timeout:
                    proc.kill()
                    raise RuntimeError("nmap scan stalled")

            if proc.poll() is not None:
                stdout_parts.append(proc.stdout.read() or "")
                stderr_parts.append(proc.stderr.read() or "")
                break

        selector.unregister(proc.stdout)
        selector.unregister(proc.stderr)
        ret = proc.wait()
        stderr_output = "".join(stderr_parts)
        if ret != 0:
            raise RuntimeError(stderr_output.strip())
        return "".join(stdout_parts)




def run_scan(
    host: str,
    ports: list[str] | None = None,
    service: bool = False,
    os_detect: bool = False,
    scripts: list[str] | None = None,
    progress_timeout: float | None = 60.0,
    timing: int | None = None,
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
    if timing is not None:
        if timing < 0 or timing > 5:
            raise ValueError("timing must be between 0 and 5")
        cmd.append(f"-T{timing}")
    if scripts is None:
        scripts = ["vuln"]
    if scripts:
        cmd += ["--script", ",".join(scripts)]
    if progress_timeout is not None:
        cmd += ["--stats-every", "5s"]
    if not ports:
        cmd += ["-p-", "-oX", "-", host]
    else:
        cmd += ["-p", ",".join(ports), "-oX", "-", host]
    output = _exec_nmap(cmd, progress_timeout)
    root = ET.fromstring(output)
    results = []
    os_name = ""
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
    if os_detect:
        m = root.find('.//osmatch')
        if m is not None:
            os_name = m.get('name', '')
    return {"os": os_name, "ports": results}


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Run nmap port scan")
    parser.add_argument("host", help="Target host")
    parser.add_argument("port_list", nargs="?", help="Comma separated ports")
    parser.add_argument("--service", action="store_true", help="Enable service version detection (-sV)")
    parser.add_argument("--os", action="store_true", help="Enable OS detection (-O)")
    parser.add_argument(
        "--script",
        help="Comma separated nmap scripts (default: vuln)",
    )
    parser.add_argument(
        "--timing",
        type=int,
        choices=range(0, 6),
        help="nmap timing template (0-5)",
    )
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
            timing=args.timing,
        )
        print(json.dumps({'host': args.host, 'os': res['os'], 'ports': res['ports']}))
    except Exception as e:
        print(json.dumps({'error': str(e)}))
        sys.exit(1)


if __name__ == '__main__':
    main()

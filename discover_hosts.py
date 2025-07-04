#!/usr/bin/env python3
import json
import sys
import subprocess
import xml.etree.ElementTree as ET
import ipaddress
import re
import os
from pathlib import Path
from urllib.request import urlopen

def _get_subnet():
    if os.name == 'nt':
        # Windows - parse output of ipconfig for IPv4 address and subnet mask.
        try:
            proc = subprocess.run(['ipconfig'], capture_output=True, text=True)
            if proc.returncode == 0:
                ip = None
                mask = None
                for line in proc.stdout.splitlines():
                    line = line.strip()
                    if not ip:
                        m = re.search(r'IPv4[^:]*:\s*(\d+\.\d+\.\d+\.\d+)', line)
                        if m:
                            ip = m.group(1)
                    if not mask:
                        m = re.search(r'Subnet[^:]*Mask[^:]*:\s*(\d+\.\d+\.\d+\.\d+)', line)
                        if m:
                            mask = m.group(1)
                    if ip and mask:
                        break
                if ip and mask:
                    try:
                        network = ipaddress.IPv4Network(f'{ip}/{mask}', strict=False)
                        return str(network)
                    except Exception:
                        pass
        except Exception:
            pass
    else:
        try:
            proc = subprocess.run(['ip', 'addr'], capture_output=True, text=True)
            if proc.returncode == 0:
                inet = None
                mask = None
                for line in proc.stdout.splitlines():
                    line = line.strip()
                    m = re.match(r'inet (\d+\.\d+\.\d+\.\d+)/(\d+)', line)
                    if m and not line.startswith('127.'):
                        inet = m.group(1)
                        masklen = int(m.group(2))
                        network = ipaddress.IPv4Network(f'{inet}/{masklen}', strict=False)
                        return str(network)
        except Exception:
            pass
    return None

def _run_arp_scan():
    try:
        proc = subprocess.run(['arp-scan', '--localnet'], capture_output=True, text=True)
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.strip())
        results = []
        for line in proc.stdout.splitlines():
            parts = line.split()  # whitespace
            if len(parts) >= 2 and re.match(r'\d+\.\d+\.\d+\.\d+', parts[0]):
                vendor = ""
                if len(parts) >= 3:
                    vendor = " ".join(parts[2:])
                results.append({'ip': parts[0], 'mac': parts[1], 'vendor': vendor})
        if results:
            return results
    except Exception:
        pass
    raise RuntimeError('arp-scan failed')

def _run_nmap_scan(subnet):
    if not subnet:
        raise ValueError('subnet is required for nmap scan')
    cmd = ['nmap', '-sn', subnet, '-oX', '-']
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True)
    except FileNotFoundError as e:
        raise RuntimeError('nmap command not found') from e
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip())
    root = ET.fromstring(proc.stdout)
    results = []
    for host in root.findall('host'):
        ip = None
        mac = ''
        vendor = ''
        for addr in host.findall('address'):
            if addr.get('addrtype') == 'ipv4':
                ip = addr.get('addr')
            elif addr.get('addrtype') == 'mac':
                mac = addr.get('addr')
                vendor = addr.get('vendor', '')
        if ip:
            results.append({'ip': ip, 'mac': mac, 'vendor': vendor})
    return results

def _lookup_vendor(mac):
    prefix = mac.upper().replace(':', '')[:6]
    db_path = Path(__file__).with_name('oui.txt')
    if db_path.exists():
        try:
            with db_path.open('r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    if line.upper().startswith(prefix):
                        return line[6:].strip()
        except Exception:
            pass
    try:
        with urlopen(f'https://api.macvendors.com/{mac}') as resp:
            return resp.read().decode('utf-8')
    except Exception:
        return ''

def main():
    subnet = None
    if len(sys.argv) > 1:
        subnet = sys.argv[1]
    subnet = subnet or _get_subnet() or '192.168.1.0/24'
    try:
        hosts = _run_arp_scan()
    except Exception:
        hosts = _run_nmap_scan(subnet)
    for h in hosts:
        if not h.get('vendor'):
            h['vendor'] = _lookup_vendor(h.get('mac', ''))
    print(json.dumps({'hosts': hosts}, ensure_ascii=False))

if __name__ == '__main__':
    main()

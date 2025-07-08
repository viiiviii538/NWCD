#!/usr/bin/env python3
import argparse
import json
import subprocess
import re
from typing import List

import dns_records

from dns_records import (
    get_spf_record,
    get_dkim_record,
    get_dmarc_record,
)


def lookup_spf(domain: str) -> str:
    """Lookup SPF record using nslookup. Returns empty string on failure."""
    try:
        result = subprocess.run(
            ["nslookup", "-type=txt", domain], capture_output=True, text=True
        )
        for line in result.stdout.splitlines():
            if "v=spf1" in line:
                return line.strip()
    except Exception:
        pass
    return ""

def check_domain(domain: str, offline: str | None = None, zone_file: str | None = None) -> dict:
    record = ''
    comment = ''

    if offline:
        try:
            with open(offline, 'r', encoding='utf-8') as f:
                data = json.load(f)
            record = data.get(domain, '')
            if record:
                comment = 'offline record'
        except Exception as e:  # pragma: no cover - file error edge case
            comment = f'failed to read offline file: {e}'

    if not record:
        try:
            record = dns_records.get_spf_record(domain, records_file=zone_file)
            if not record and not comment:
                comment = 'No SPF record found'
        except Exception as e:  # pragma: no cover - subprocess error
            comment = f'Failed to check SPF record: {e}'

    dkim = dns_records.get_dkim_record(domain, records_file=zone_file)
    dmarc = dns_records.get_dmarc_record(domain, records_file=zone_file)
    status = 'safe' if record and dkim and dmarc else 'danger'
    return {
        'domain': domain,
        'spf': record,
        'dkim': dkim,
        'dmarc': dmarc,
        'status': status,
        'comment': comment,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description='Verify domain sender records')
    parser.add_argument('pos_domains', nargs='*', help='Domain name(s) to check')
    parser.add_argument('--domains', nargs='+', help='Domain name(s) to check')
    parser.add_argument('--offline', help='Path to offline SPF record JSON file')
    parser.add_argument('--zone-file', help='Path to DNS zone file')
    args = parser.parse_args()

    domains: List[str] = []
    if args.domains:
        domains.extend(args.domains)
    if args.pos_domains:
        domains.extend(args.pos_domains)
    if not domains:
        parser.error('No domain specified')

    for d in domains:
        res = check_domain(d, offline=args.offline, zone_file=args.zone_file)
        print(json.dumps(res, ensure_ascii=False))

if __name__ == '__main__':
    main()

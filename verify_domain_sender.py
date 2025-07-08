#!/usr/bin/env python3
import argparse
import json

from dns_records import (
    get_spf_record,
    get_dkim_record,
    get_dmarc_record,
)

def main() -> None:
    parser = argparse.ArgumentParser(
        description='Verify SPF, DKIM and DMARC records for a domain'
    )
    parser.add_argument('domain', help='Domain name to check')
    parser.add_argument('--selector', default='default', help='DKIM selector')
    parser.add_argument('--zone-file', help='Path to zone file for offline mode')
    args = parser.parse_args()

    spf = get_spf_record(args.domain, records_file=args.zone_file)
    dkim = get_dkim_record(args.domain, selector=args.selector, records_file=args.zone_file)
    dmarc = get_dmarc_record(args.domain, records_file=args.zone_file)

    result = {
        'domain': args.domain,
        'spf': spf,
        'dkim': dkim,
        'dmarc': dmarc,
        'spf_status': 'safe' if spf else 'danger',
        'dkim_status': 'safe' if dkim else 'danger',
        'dmarc_status': 'safe' if dmarc else 'danger',
    }
    print(json.dumps(result, ensure_ascii=False))

if __name__ == '__main__':
    main()

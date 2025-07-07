#!/usr/bin/env python3
import argparse
import json
import subprocess

def lookup_spf(domain: str) -> str:
    result = subprocess.run(['nslookup', '-type=txt', domain], capture_output=True, text=True)
    for line in result.stdout.splitlines():
        if 'v=spf1' in line:
            return line.strip()
    return ''

def main() -> None:
    parser = argparse.ArgumentParser(description='Verify domain SPF record')
    parser.add_argument('domain', help='Domain name to check')
    parser.add_argument('--offline', help='Path to offline SPF record JSON file')
    args = parser.parse_args()

    record = ''
    comment = ''

    if args.offline:
        try:
            with open(args.offline, 'r', encoding='utf-8') as f:
                data = json.load(f)
            record = data.get(args.domain, '')
            if record:
                comment = 'offline record'
        except Exception as e:
            comment = f'failed to read offline file: {e}'

    if not record:
        try:
            record = lookup_spf(args.domain)
            if not record:
                comment = 'No SPF record found'
        except Exception as e:
            comment = f'Failed to check SPF record: {e}'

    status = 'safe' if record else 'danger'
    result = {
        'domain': args.domain,
        'record': record,
        'status': status,
        'comment': comment,
    }
    print(json.dumps(result, ensure_ascii=False))

if __name__ == '__main__':
    main()

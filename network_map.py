#!/usr/bin/env python3
"""Discover network hosts and output the result as JSON."""

import json
import sys

from discover_hosts import discover_hosts


def main() -> int:
    """Execute host discovery and print results."""
    subnet = sys.argv[1] if len(sys.argv) > 1 else None
    try:
        hosts = discover_hosts(subnet)
        print(json.dumps(hosts, ensure_ascii=False))
        print("Host discovery succeeded", file=sys.stdout)
        return 0
    except Exception as exc:
        print(f"Host discovery failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

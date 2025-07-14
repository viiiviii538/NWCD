#!/usr/bin/env python3
"""Check availability of network scanning tools."""
import json
import shutil
import sys
from typing import List

TOOLS = ["arp-scan", "nmap"]

def check_missing_tools() -> List[str]:
    """Return list of missing tools from TOOLS."""
    return [t for t in TOOLS if shutil.which(t) is None]


def main() -> None:
    missing = check_missing_tools()
    print(json.dumps({"missing": missing}, ensure_ascii=False))
    sys.exit(0 if not missing else 1)


if __name__ == "__main__":
    main()

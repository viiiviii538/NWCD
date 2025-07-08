import json
import re
import subprocess
from typing import Optional


def _query_txt(name: str) -> str:
    """Query TXT record for name using nslookup."""
    try:
        proc = subprocess.run(
            ["nslookup", "-type=txt", name], capture_output=True, text=True, timeout=5
        )
        if proc.returncode != 0:
            return ""
        for line in proc.stdout.splitlines():
            m = re.search(r'"([^"]+)"', line)
            if m:
                return m.group(1)
    except Exception:
        pass
    return ""


def _find_in_file(path: str, name: str) -> str:
    """Return the first TXT record for name found in file."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                if name in line and "TXT" in line.upper():
                    m = re.search(r'"([^"]+)"', line)
                    if m:
                        return m.group(1)
    except Exception:
        pass
    return ""


def get_spf_record(domain: str, records_file: Optional[str] = None) -> str:
    """Return SPF record for domain."""
    name = domain
    if records_file:
        return _find_in_file(records_file, name)
    return _query_txt(name)


def get_dkim_record(domain: str, selector: str = "default", records_file: Optional[str] = None) -> str:
    """Return DKIM record for selector._domainkey.domain."""
    name = f"{selector}._domainkey.{domain}"
    if records_file:
        return _find_in_file(records_file, name)
    return _query_txt(name)


def get_dmarc_record(domain: str, records_file: Optional[str] = None) -> str:
    """Return DMARC record for _dmarc.domain."""
    name = f"_dmarc.{domain}"
    if records_file:
        return _find_in_file(records_file, name)
    return _query_txt(name)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Retrieve DNS TXT records")
    parser.add_argument("domain", help="Domain to query")
    parser.add_argument("--selector", default="default", help="DKIM selector")
    parser.add_argument("--zone-file", help="Path to zone file for offline mode")
    args = parser.parse_args()

    spf = get_spf_record(args.domain, records_file=args.zone_file)
    dkim = get_dkim_record(
        args.domain, selector=args.selector, records_file=args.zone_file
    )
    dmarc = get_dmarc_record(args.domain, records_file=args.zone_file)
    print(json.dumps({"spf": spf, "dkim": dkim, "dmarc": dmarc}))

#!/usr/bin/env python3
"""Combined utility script for network and system checks."""
import argparse
import json
import os
import subprocess
import sys
from typing import Optional

try:
    import speedtest
except ImportError:  # pragma: no cover - handled in tests
    speedtest = None

REQUIRED_PYTHON = (3, 10)


def check_python_version() -> bool:
    """Return True if running interpreter is >= REQUIRED_PYTHON."""
    return sys.version_info >= REQUIRED_PYTHON


def ensure_python_version() -> None:
    if not check_python_version():
        sys.stderr.write(
            f"Python {REQUIRED_PYTHON[0]}.{REQUIRED_PYTHON[1]} or higher is required. "
            f"Current version: {sys.version.split()[0]}\n"
        )
        sys.exit(1)
    print("Python version is sufficient.")


def measure_speed() -> Optional[dict[str, float]]:
    """Measure download/upload speed and ping using speedtest-cli."""
    if speedtest is None:
        raise RuntimeError("speedtest module not available")
    try:
        st = speedtest.Speedtest()
        st.get_best_server()
        download = st.download()
        upload = st.upload()
        ping = st.results.ping
        return {
            "download": download / 1e6,
            "upload": upload / 1e6,
            "ping": float(ping),
        }
    except speedtest.ConfigRetrievalError as e:
        print(f"speedtest config error: {e}", file=sys.stderr)
    except Exception as e:  # pragma: no cover - unexpected errors
        print(f"speedtest failed: {e}", file=sys.stderr)
    return None


def get_defender_status() -> Optional[bool]:
    """Return True if Windows Defender real-time protection is enabled."""
    if os.name != "nt":
        return None
    try:
        cmd = ["powershell", "-Command", "(Get-MpComputerStatus).RealTimeProtectionEnabled"]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode == 0:
            out = proc.stdout.strip().lower()
            return out in ("true", "1", "yes")
    except Exception:  # pragma: no cover - defensive
        pass
    return None


def get_firewall_status() -> Optional[bool]:
    """Return True if firewall is enabled."""
    if os.name == "nt":
        try:
            cmd = ["netsh", "advfirewall", "show", "allprofiles"]
            proc = subprocess.run(cmd, capture_output=True, text=True)
            if proc.returncode == 0:
                for line in proc.stdout.splitlines():
                    line = line.strip()
                    if "State" in line or "\u72b6\u614b" in line:  # 状態
                        line_upper = line.upper()
                        if "ON" in line_upper or "\u6709\u52b9" in line:
                            return True
                        if "OFF" in line_upper or "\u7121\u52b9" in line:
                            return False
        except Exception:  # pragma: no cover - defensive
            pass
    else:
        try:
            proc = subprocess.run(["ufw", "status"], capture_output=True, text=True)
            if proc.returncode == 0:
                out = proc.stdout.lower()
                if "status: active" in out:
                    return True
                if "inactive" in out:
                    return False
        except Exception:  # pragma: no cover - defensive
            pass
    return None


def print_json(obj: object) -> None:
    print(json.dumps(obj, ensure_ascii=False))


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("network-speed", help="Measure network speed")
    sub.add_parser("firewall-status", help="Check firewall and Defender status")
    sub.add_parser("check-python", help="Ensure Python version >= 3.10")

    args = parser.parse_args(argv)

    if args.cmd == "network-speed":
        res = measure_speed()
        print_json(res)
    elif args.cmd == "firewall-status":
        print_json({
            "defender_enabled": get_defender_status(),
            "firewall_enabled": get_firewall_status(),
        })
    elif args.cmd == "check-python":
        ensure_python_version()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
import json
import os
import subprocess


def get_defender_status():
    """Return True if Windows Defender real-time protection is enabled."""
    if os.name != 'nt':
        return None
    try:
        cmd = [
            "powershell",
            "-Command",
            "(Get-MpComputerStatus).RealTimeProtectionEnabled"
        ]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode == 0:
            out = proc.stdout.strip().lower()
            return out in ("true", "1", "yes")
    except Exception:
        pass
    return None


def get_firewall_status():
    """Return True if firewall is enabled."""
    if os.name == 'nt':
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
        except Exception:
            pass
    else:
        # Try ufw on Linux
        try:
            proc = subprocess.run(["ufw", "status"], capture_output=True, text=True)
            if proc.returncode == 0:
                out = proc.stdout.lower()
                if "status: active" in out:
                    return True
                if "inactive" in out:
                    return False
        except Exception:
            pass
    return None


def main():
    defender = get_defender_status()
    firewall = get_firewall_status()
    print(json.dumps({
        "defender_enabled": defender,
        "firewall_enabled": firewall,
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()

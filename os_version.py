#!/usr/bin/env python3
"""Utility functions for detecting the Windows OS version."""

import sys

# Mapping of (major, minor) tuples to human-readable names
_WINDOWS_VERSION_MAP = {
    (5, 1): "Windows XP",
    (5, 2): "Windows XP",
    (6, 0): "Windows Vista",
    (6, 1): "Windows 7",
    (6, 2): "Windows 8",
    (6, 3): "Windows 8.1",
    (10, 0): "Windows 10",
}


def get_windows_version() -> str | None:
    """Return a human readable Windows version or ``None`` on non-Windows."""
    if sys.platform != "win32":
        return None
    info = sys.getwindowsversion()
    return _WINDOWS_VERSION_MAP.get((info.major, info.minor), f"Windows {info.major}.{info.minor}")


def main() -> None:
    version = get_windows_version()
    if version is None:
        print("Non-Windows")
    else:
        print(version)


if __name__ == "__main__":
    main()

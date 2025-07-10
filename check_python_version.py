#!/usr/bin/env python3
"""Ensure the running interpreter is Python 3.10 or newer."""
import sys

REQUIRED = (3, 10)
if sys.version_info < REQUIRED:
    sys.stderr.write(
        f"Python {REQUIRED[0]}.{REQUIRED[1]} or higher is required. "
        f"Current version: {sys.version.split()[0]}\n"
    )
    sys.exit(1)

print("Python version is sufficient.")

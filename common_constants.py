"""Common constants shared across modules."""

import os

DANGER_COUNTRIES = {"RU", "CN", "KP"}  # Russia, China, North Korea

SAFE_COUNTRIES = {"JP", "US", "GB", "DE", "FR", "CA", "AU"}

# ANSI color escape sequences for console output. Disabled when the
# ``NWCD_NO_COLOR`` environment variable is set.
if os.getenv("NWCD_NO_COLOR"):
    RED = ""
    RESET = ""
else:
    RED = "\033[31m"
    RESET = "\033[0m"

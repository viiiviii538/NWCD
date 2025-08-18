#!/usr/bin/env python3
"""Discover network hosts and output the result as JSON.

This module calls ``discover_hosts`` to obtain a list of hosts and prints the
list in JSON format. A success message is written to stdout while failures are
reported to stderr.
"""

from __future__ import annotations

import argparse
import json
import logging
import sys

from discover_hosts import discover_hosts


class _StdoutFilter(logging.Filter):
    """Filter that only allows records below ERROR level."""

    def filter(self, record: logging.LogRecord) -> bool:  # noqa: D401 - self-explanatory
        return record.levelno < logging.ERROR


def _configure_logging() -> logging.Logger:
    """Configure logger to split INFO to stdout and ERROR to stderr."""
    logger = logging.getLogger("network_map")
    logger.setLevel(logging.INFO)

    stdout_handler = logging.StreamHandler(sys.stdout)
    stdout_handler.addFilter(_StdoutFilter())
    stderr_handler = logging.StreamHandler(sys.stderr)
    stderr_handler.setLevel(logging.ERROR)

    logger.addHandler(stdout_handler)
    logger.addHandler(stderr_handler)
    return logger


def _parse_args(argv: list[str]) -> argparse.Namespace:
    """Return parsed command line arguments."""
    parser = argparse.ArgumentParser(description="Discover network hosts")
    parser.add_argument(
        "subnet",
        nargs="?",
        help="subnet to scan in CIDR notation (e.g. 192.168.1.0/24)",
    )
    return parser.parse_args(argv)


def main() -> int:
    """Execute host discovery and print results."""
    logger = _configure_logging()
    args = _parse_args(sys.argv[1:])
    try:
        hosts = discover_hosts(args.subnet)
        print(json.dumps({"hosts": hosts}, ensure_ascii=False))
        logger.info("Host discovery succeeded")
        return 0
    except Exception as exc:  # pragma: no cover - required for test coverage
        logger.error("Host discovery failed: %s", exc)
        return 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Measure network speed using speedtest-cli."""
import json
try:
    import speedtest
except ImportError:  # pragma: no cover - handled in tests
    speedtest = None


def measure_speed() -> dict[str, float] | None:
    if speedtest is None:
        raise RuntimeError("speedtest module not available")
    try:
        st = speedtest.Speedtest()
        st.get_best_server()
        download = st.download()
        upload = st.upload()
        ping = st.results.ping
        return {
            "download": download / 1e6,  # Mbps
            "upload": upload / 1e6,
            "ping": float(ping),
        }
    except speedtest.ConfigRetrievalError as e:
        print(f"speedtest config error: {e}")
    except Exception as e:
        print(f"speedtest failed: {e}")
    return None


def main() -> None:
    data = measure_speed()
    print(json.dumps(data))


if __name__ == "__main__":
    main()

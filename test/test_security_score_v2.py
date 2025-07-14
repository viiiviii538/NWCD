import unittest
import pytest
import json
import tempfile

pytest.importorskip("graphviz")

from security_score import calc_security_score, load_config, DANGER_PORTS
from report_utils import calc_utm_items


class CalcSecurityScoreV2Test(unittest.TestCase):
    def test_score_capping_and_utm(self):
        data = {
            "danger_ports": ["3389"] * 20,
            "geoip": "RU",
            "ssl": "self-signed",
            "open_port_count": 20,
            "dns_fail_rate": 1.0,
            "intl_traffic_ratio": 0.9,
            "ip_conflict": True,
        }
        res = calc_security_score(data)
        self.assertEqual(res["score"], 0.0)
        utm = calc_utm_items(res["score"], ["3389"], ["RU"])
        self.assertEqual(sorted(utm), ["firewall", "ips", "web_filter"])

    def test_calc_utm_items_threshold(self):
        res = calc_security_score({"open_port_count": 1})
        utm = calc_utm_items(res["score"], ["22"], ["JP"])
        self.assertEqual(utm, ["firewall"])

    def test_load_config_from_file(self):
        cfg = {
            "weights": {"high": 1.0, "medium": 1.0, "low": 1.0},
            "danger_ports": ["9999"],
        }
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            json.dump(cfg, f)
            path = f.name
        try:
            load_config(path)
            res = calc_security_score({"danger_ports": ["9999"], "open_port_count": 1})
            self.assertEqual(res["high_risk"], 1)
            self.assertEqual(res["low_risk"], 1)
            self.assertAlmostEqual(res["score"], 8.0, places=1)
            self.assertIn("9999", DANGER_PORTS)
        finally:
            load_config(None)


if __name__ == "__main__":
    unittest.main()

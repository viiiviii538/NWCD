import unittest
import json
import tempfile
from security_score import (
    calc_security_score,
    HIGH_WEIGHT,
    MEDIUM_WEIGHT,
    LOW_WEIGHT,
    load_config,
    DANGER_PORTS,
)
from report_utils import calc_utm_items


class CalcSecurityTest(unittest.TestCase):
    def test_empty_data(self):
        res = calc_security_score({})
        self.assertEqual(res["score"], 10.0)
        self.assertEqual(res["high_risk"], 0)
        self.assertEqual(res["medium_risk"], 0)
        self.assertEqual(res["low_risk"], 0)

    def test_single_high(self):
        res = calc_security_score({"danger_ports": ["3389"]})
        self.assertEqual(res["high_risk"], 1)
        self.assertAlmostEqual(res["score"], 5.5, places=1)

    def test_mixed_levels(self):
        data = {"danger_ports": 1, "ssl": "invalid", "open_port_count": 2}
        res = calc_security_score(data)
        self.assertEqual(res["high_risk"], 2)
        self.assertEqual(res["medium_risk"], 0)
        self.assertEqual(res["low_risk"], 1)
        expected = 10 - 2 * HIGH_WEIGHT - 1 * LOW_WEIGHT
        self.assertAlmostEqual(res["score"], expected, places=1)

    def test_new_metrics(self):
        data = {
            "firewall_enabled": False,
            "defender_enabled": False,
            "os_version": "Windows XP",
            "smbv1": True,
        }
        res = calc_security_score(data)
        self.assertEqual(res["high_risk"], 4)
        self.assertEqual(res["score"], 0.0)

    def test_utm_bonus(self):
        data = {"danger_ports": ["3389"], "utm_active": True}
        res = calc_security_score(data)
        expected = 10 - HIGH_WEIGHT + 2.0
        if expected > 10:
            expected = 10.0
        self.assertAlmostEqual(res["score"], expected, places=1)



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

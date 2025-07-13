import unittest
from security_score import (
    calc_security_score,
    HIGH_WEIGHT,
    MEDIUM_WEIGHT,
    LOW_WEIGHT,
)


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


if __name__ == "__main__":
    unittest.main()

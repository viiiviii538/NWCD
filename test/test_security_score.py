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
        self.assertAlmostEqual(res["score"], 9.0, places=1)

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
        self.assertEqual(res["score"], 6.0)

    def test_os_version_points(self):
        score, warnings = calc_security_score([], [], os_version="Windows 7")
        self.assertEqual(score, 0.7)
        self.assertEqual(warnings, [])

    def test_http_port(self):
        score, warnings = calc_security_score(["80"], ["JP"])
        self.assertEqual(score, 1.0)
        self.assertEqual(warnings, [])

    def test_rdp_port_warning(self):
        score, warnings = calc_security_score(["3389"], ["JP"])
        self.assertEqual(score, 4.0)
        self.assertTrue(any("RDP port open" in w for w in warnings))

    def test_rdp_and_russia(self):
        score, warnings = calc_security_score(["3389"], ["RU"])
        self.assertEqual(score, 7.0)
        self.assertTrue(any("RDP" in w for w in warnings))
        self.assertTrue(any("RU" in w for w in warnings))

    def test_danger_country_and_cap(self):
        score, warnings = calc_security_score(["3389", "445"], ["CN"])
        self.assertEqual(score, 9.0)
        self.assertEqual(len(warnings), 2)

    def test_score_capped(self):
        ports = ["3389", "445", "23", "22", "21", "80", "443"]
        score, _ = calc_security_score(ports, ["RU", "CN"])
        self.assertEqual(score, 10.0)

    def test_os_version_points(self):
        score, warnings = calc_security_score([], [], os_version="Windows 7")
        self.assertEqual(score, 0.7)
        self.assertEqual(warnings, [])


if __name__ == "__main__":
    unittest.main()

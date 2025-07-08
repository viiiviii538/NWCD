import unittest
from security_score import calc_security_score
from report_utils import calc_utm_items


class CalcSecurityScoreV2Test(unittest.TestCase):
    def test_empty_inputs(self):
        score, warnings = calc_security_score([], [])
        self.assertEqual(score, 0.0)
        self.assertEqual(warnings, [])

    def test_single_dangerous_port(self):
        score, warnings = calc_security_score(["3389"], ["JP"])
        self.assertEqual(score, 4.0)
        self.assertTrue(any("RDP" in w for w in warnings))

    def test_dangerous_country(self):
        score, warnings = calc_security_score([], ["CN"])
        self.assertEqual(score, 3.0)
        self.assertTrue(any("CN" in w for w in warnings))

    def test_utm_reduction(self):

        base_score, _ = calc_security_score(["3389"], ["RU"])
        utm_score, _ = calc_security_score(["3389"], ["RU"], has_utm=True)
        self.assertEqual(utm_score, round(base_score * 0.8, 1))
        self.assertLess(utm_score, base_score)

    def test_score_capping(self):
        ports = ["3389", "445", "23", "22", "21", "80"]

        score, _ = calc_security_score(ports, ["RU", "CN"])
        self.assertEqual(score, 10.0)
        utm = calc_utm_items(score, ports, ["RU", "CN"])
        self.assertEqual(utm, ["firewall", "ips", "web_filter"])

    def test_calc_utm_items(self):
        ports = ["3389"]
        countries = ["CN"]
        score, _ = calc_security_score(ports, countries, True)
        utm = calc_utm_items(score, ports, countries)
        self.assertEqual(utm, ["firewall", "ips", "web_filter"])

    def test_mixed_countries(self):
        score, warnings = calc_security_score([], ["JP", "RU"])
        self.assertEqual(score, 3.0)
        self.assertTrue(any("RU" in w for w in warnings))
        utm = calc_utm_items(score, [], ["JP", "RU"])
        self.assertEqual(utm, ["web_filter"])

    def test_unknown_port(self):
        score, warnings = calc_security_score(["9999"], ["JP"])
        self.assertEqual(score, 0.5)
        self.assertEqual(warnings, [])
        self.assertEqual(calc_utm_items(score, ["9999"], ["JP"]), ["firewall"])


if __name__ == "__main__":
    unittest.main()

import unittest
from risk_score import calc_risk_score


class CalcRiskTest(unittest.TestCase):
    def test_no_inputs(self):
        score, warnings = calc_risk_score([], [])
        self.assertEqual(score, 0.0)
        self.assertEqual(warnings, [])

    def test_http_port(self):
        score, warnings = calc_risk_score(["80"], ["JP"])
        self.assertEqual(score, 1.0)
        self.assertEqual(warnings, [])

    def test_rdp_port_warning(self):
        score, warnings = calc_risk_score(["3389"], ["JP"])
        self.assertEqual(score, 4.0)
        self.assertTrue(any("RDP port open" in w for w in warnings))

    def test_rdp_and_russia(self):
        score, warnings = calc_risk_score(["3389"], ["RU"])
        self.assertEqual(score, 7.0)
        self.assertTrue(any("RDP" in w for w in warnings))
        self.assertTrue(any("RU" in w for w in warnings))

    def test_danger_country_and_cap(self):
        score, warnings = calc_risk_score(["3389", "445"], ["CN"])
        self.assertEqual(score, 9.0)
        self.assertEqual(len(warnings), 2)

    def test_score_capped(self):
        ports = ["3389", "445", "23", "22", "21", "80", "443"]
        score, _ = calc_risk_score(ports, ["RU", "CN"])
        self.assertEqual(score, 10.0)


if __name__ == "__main__":
    unittest.main()

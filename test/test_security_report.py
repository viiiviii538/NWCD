import unittest
from security_report import calc_score

class CalcSecurityScoreTest(unittest.TestCase):
    def test_all_safe(self):
        score, risks, utm = calc_score([], True, True, 'JP')
        self.assertEqual(score, 10.0)
        self.assertEqual(risks, [])
        self.assertEqual(utm, [])

    def test_high_risk_port_and_invalids(self):
        score, risks, utm = calc_score(['3389'], False, False, 'RU')
        self.assertAlmostEqual(score, 7.7, places=2)
        self.assertEqual(len(risks), 4)
        self.assertTrue(all('risk' in r and 'counter' in r for r in risks))
        self.assertEqual(utm, [])

    def test_many_open_ports(self):
        ports = [str(i) for i in range(1, 11)]
        score, risks, _ = calc_score(ports, True, True, 'JP')
        self.assertAlmostEqual(score, 9.8, places=2)
        self.assertTrue(risks)
        self.assertTrue(all('counter' in r for r in risks))

if __name__ == '__main__':
    unittest.main()

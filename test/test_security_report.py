import unittest
import pytest

pytest.importorskip("graphviz")

from security_report import calc_score


class CalcScoreTest(unittest.TestCase):
    def test_all_safe(self):
        score, risks, utm = calc_score([], True, True, True, True, 'JP')
        self.assertEqual(score, 10.0)
        self.assertEqual(risks, [])
        self.assertEqual(utm, [])

    def test_high_risk_port_and_invalids(self):
        score, risks, utm = calc_score(['3389'], 'self-signed', False, False, False, 'RU')
        self.assertAlmostEqual(score, 5.7, places=1)
        self.assertEqual(len(risks), 6)
        self.assertTrue(all('risk' in r and 'counter' in r for r in risks))
        self.assertEqual(utm, ['firewall', 'web_filter'])

    def test_many_open_ports(self):
        ports = [str(i) for i in range(1, 11)]
        score, risks, utm = calc_score(ports, True, True, True, True, 'JP')
        self.assertAlmostEqual(score, 9.5, places=1)
        self.assertTrue(risks)
        self.assertTrue(all('counter' in r for r in risks))
        self.assertEqual(utm, ['firewall'])


if __name__ == '__main__':
    unittest.main()

import unittest
from security_score import calc_security_score
from report_utils import calc_utm_items


class CalcSecurityScoreV2Test(unittest.TestCase):
    def test_score_capping_and_utm(self):
        data = {
            "danger_ports": ["3389"] * 20,
            "geoip": "RU",
            "ssl": False,
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


if __name__ == "__main__":
    unittest.main()

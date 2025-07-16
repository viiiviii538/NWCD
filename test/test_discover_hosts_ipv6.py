import unittest
from unittest.mock import patch, MagicMock
import network_utils

class DiscoverHostsIPv6Test(unittest.TestCase):
    def test_run_nmap_scan_ipv6(self):
        xml = """<nmaprun><host><address addr='fe80::1' addrtype='ipv6'/><address addr='00:11:22:33:44:55' addrtype='mac' vendor='ACME'/></host></nmaprun>"""
        with patch('subprocess.run') as m:
            m.return_value = MagicMock(returncode=0, stdout=xml)
            res = network_utils._run_nmap_scan('fe80::/64')
            m.assert_called_with(
                ['nmap', '-6', '-sn', 'fe80::/64', '-oX', '-'],
                capture_output=True,
                text=True,
                timeout=network_utils.SCAN_TIMEOUT,
            )
            self.assertEqual(res[0]['ip'], 'fe80::1')
            self.assertEqual(res[0]['mac'], '00:11:22:33:44:55')

if __name__ == '__main__':
    unittest.main()

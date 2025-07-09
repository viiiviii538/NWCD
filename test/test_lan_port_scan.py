import unittest
from unittest.mock import patch
import lan_port_scan

class LanPortScanJsonTest(unittest.TestCase):
    @patch('lan_port_scan.run_scan')
    @patch('lan_port_scan._run_arp_scan')
    def test_basic_json(self, mock_arp, mock_scan):
        mock_arp.return_value = [{'ip': '192.168.1.2', 'mac': 'aa', 'vendor': 'X'}]
        mock_scan.return_value = [{'port': '22', 'state': 'open', 'service': 'ssh'}]
        res = lan_port_scan.scan_hosts('192.168.1.0/24', ['22'])
        self.assertIsInstance(res, list)
        self.assertEqual(res[0]['ip'], '192.168.1.2')
        self.assertIn('ports', res[0])
        self.assertEqual(res[0]['ports'][0]['port'], '22')

    @patch('lan_port_scan.run_scan')
    @patch('lan_port_scan._lookup_vendor', return_value='')
    @patch('lan_port_scan._run_nmap_scan')
    @patch('lan_port_scan._run_arp_scan', side_effect=RuntimeError('no arp'))
    def test_fallback_nmap(self, mock_arp, mock_nmap, mock_lookup, mock_scan):
        mock_nmap.return_value = [{'ip': '10.0.0.5', 'mac': '', 'vendor': ''}]
        mock_scan.return_value = []
        res = lan_port_scan.scan_hosts('10.0.0.0/24', ['80'])
        self.assertEqual(res[0]['ip'], '10.0.0.5')
        self.assertEqual(res[0]['ports'], [])

    @patch('lan_port_scan.run_scan')
    @patch('lan_port_scan._run_arp_scan')
    def test_ipv6_hosts(self, mock_arp, mock_scan):
        mock_arp.return_value = [{'ip': 'fe80::1', 'mac': 'aa', 'vendor': 'X'}]
        mock_scan.return_value = []
        res = lan_port_scan.scan_hosts('fe80::/64', ['80'])
        mock_scan.assert_called_with('fe80::1', ['80'], service=False, os_detect=False, scripts=None)
        self.assertEqual(res[0]['ip'], 'fe80::1')

if __name__ == '__main__':
    unittest.main()

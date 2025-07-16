import unittest
import subprocess
from unittest.mock import patch
import port_scan


class PortScanScriptTest(unittest.TestCase):
    def test_run_scan_uses_all_ports_when_empty(self):
        xml = "<nmaprun></nmaprun>"
        with patch('port_scan._exec_nmap') as m:
            m.return_value = xml
            res = port_scan.run_scan('1.1.1.1', [])
            called_cmd = m.call_args[0][0]
            self.assertEqual(
                called_cmd,
                ['nmap', '--script', 'vuln', '--stats-every', '5s', '-p-', '-oX', '-', '1.1.1.1']
            )
            self.assertIn('ports', res)

    def test_run_scan_with_options(self):
        xml = "<nmaprun></nmaprun>"
        with patch('port_scan._exec_nmap') as m:
            m.return_value = xml
            res = port_scan.run_scan('1.1.1.1', [], service=True, os_detect=True, scripts=['vuln'])
            called_cmd = m.call_args[0][0]
            self.assertEqual(
                called_cmd,
                ['nmap', '-sV', '-O', '--script', 'vuln', '--stats-every', '5s', '-p-', '-oX', '-', '1.1.1.1']
            )
            self.assertIn('ports', res)

    def test_run_scan_ipv6_adds_flag(self):
        xml = "<nmaprun></nmaprun>"
        with patch('port_scan._exec_nmap') as m:
            m.return_value = xml
            res = port_scan.run_scan('fe80::1', [])
            called_cmd = m.call_args[0][0]
            self.assertEqual(
                called_cmd,
                ['nmap', '-6', '--script', 'vuln', '--stats-every', '5s', '-p-', '-oX', '-', 'fe80::1']
            )
            self.assertIn('ports', res)

    def test_run_scan_custom_script_overrides_default(self):
        xml = "<nmaprun></nmaprun>"
        with patch('port_scan._exec_nmap') as m:
            m.return_value = xml
            res = port_scan.run_scan('1.1.1.1', [], scripts=['http-enum'])
            called_cmd = m.call_args[0][0]
            self.assertEqual(
                called_cmd,
                ['nmap', '--script', 'http-enum', '--stats-every', '5s', '-p-', '-oX', '-', '1.1.1.1']
            )
            self.assertIn('ports', res)

    def test_run_scan_parses_os(self):
        xml = "<nmaprun><host><os><osmatch name='Microsoft Windows 11' /></os></host></nmaprun>"
        with patch('port_scan._exec_nmap') as m:
            m.return_value = xml
            res = port_scan.run_scan('1.1.1.1', [], os_detect=True)
            self.assertEqual(res['os'], 'Microsoft Windows 11')

    def test_run_scan_timeout_error(self):
        with patch('port_scan._exec_nmap') as m:
            m.side_effect = RuntimeError('nmap scan stalled')
            with self.assertRaises(RuntimeError):
                port_scan.run_scan('1.1.1.1', [], progress_timeout=None)

if __name__ == '__main__':
    unittest.main()

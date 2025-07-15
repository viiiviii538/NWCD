import unittest
from unittest.mock import patch, MagicMock
import subprocess
import port_scan


class PortScanScriptTest(unittest.TestCase):
    def test_run_scan_uses_all_ports_when_empty(self):
        xml = "<nmaprun></nmaprun>"
        with patch('subprocess.run') as m:
            m.return_value = MagicMock(returncode=0, stdout=xml)
            res = port_scan.run_scan('1.1.1.1', [])
            m.assert_called_with(
                [
                    'nmap', '--script', 'vuln', '-p-', '-oX', '-', '1.1.1.1'
                ],
                capture_output=True,
                text=True,
                timeout=port_scan.SCAN_TIMEOUT,
            )
            assert 'ports' in res

    def test_run_scan_with_options(self):
        xml = "<nmaprun></nmaprun>"
        with patch('subprocess.run') as m:
            m.return_value = MagicMock(returncode=0, stdout=xml)
            res = port_scan.run_scan('1.1.1.1', [], service=True, os_detect=True, scripts=['vuln'])
            m.assert_called_with(
                [
                    'nmap', '-sV', '-O', '--script', 'vuln', '-p-', '-oX', '-', '1.1.1.1'
                ],
                capture_output=True,
                text=True,
                timeout=port_scan.SCAN_TIMEOUT,
            )
            assert 'ports' in res

    def test_run_scan_ipv6_adds_flag(self):
        xml = "<nmaprun></nmaprun>"
        with patch('subprocess.run') as m:
            m.return_value = MagicMock(returncode=0, stdout=xml)
            res = port_scan.run_scan('fe80::1', [])
            m.assert_called_with(
                [
                    'nmap', '-6', '--script', 'vuln', '-p-', '-oX', '-', 'fe80::1'
                ],
                capture_output=True,
                text=True,
                timeout=port_scan.SCAN_TIMEOUT,
            )
            assert 'ports' in res

    def test_run_scan_custom_script_overrides_default(self):
        xml = "<nmaprun></nmaprun>"
        with patch('subprocess.run') as m:
            m.return_value = MagicMock(returncode=0, stdout=xml)
            res = port_scan.run_scan('1.1.1.1', [], scripts=['http-enum'])
            m.assert_called_with(
                [
                    'nmap', '--script', 'http-enum', '-p-', '-oX', '-', '1.1.1.1'
                ],
                capture_output=True,
                text=True,
                timeout=port_scan.SCAN_TIMEOUT,
            )
            assert 'ports' in res

    def test_run_scan_parses_os(self):
        xml = "<nmaprun><host><os><osmatch name='Microsoft Windows 11' /></os></host></nmaprun>"
        with patch('subprocess.run') as m:
            m.return_value = MagicMock(returncode=0, stdout=xml)
            res = port_scan.run_scan('1.1.1.1', [], os_detect=True)
            self.assertEqual(res['os'], 'Microsoft Windows 11')

    def test_run_scan_timeout_error(self):
        with patch('subprocess.run') as m:
            m.side_effect = subprocess.TimeoutExpired(cmd='nmap', timeout=1)
            with self.assertRaises(RuntimeError):
                port_scan.run_scan('1.1.1.1', [], timeout=1)

if __name__ == '__main__':
    unittest.main()

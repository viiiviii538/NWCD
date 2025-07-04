import unittest
from unittest.mock import patch, MagicMock
import port_scan

class PortScanScriptTest(unittest.TestCase):
    def test_run_scan_uses_all_ports_when_empty(self):
        xml = "<nmaprun></nmaprun>"
        with patch('subprocess.run') as m:
            m.return_value = MagicMock(returncode=0, stdout=xml)
            port_scan.run_scan('1.1.1.1', [])
            m.assert_called_with([
                'nmap', '-p-', '-oX', '-', '1.1.1.1'
            ], capture_output=True, text=True)

if __name__ == '__main__':
    unittest.main()

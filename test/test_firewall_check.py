import unittest
from unittest.mock import patch, MagicMock
import system_utils as firewall_check


class FirewallCheckTest(unittest.TestCase):
    @patch('system_utils.os.name', 'nt')
    @patch('system_utils.subprocess.run')
    def test_get_defender_status_enabled(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout='True\n')
        self.assertTrue(firewall_check.get_defender_status())

    @patch('system_utils.os.name', 'nt')
    @patch('system_utils.subprocess.run')
    def test_get_defender_status_disabled(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout='False\n')
        self.assertFalse(firewall_check.get_defender_status())

    @patch('system_utils.os.name', 'posix')
    def test_get_defender_status_non_windows(self):
        self.assertIsNone(firewall_check.get_defender_status())

    @patch('system_utils.os.name', 'nt')
    @patch('system_utils.subprocess.run')
    def test_get_firewall_status_windows_on(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout='State ON\n')
        self.assertTrue(firewall_check.get_firewall_status())

    @patch('system_utils.os.name', 'nt')
    @patch('system_utils.subprocess.run')
    def test_get_firewall_status_windows_off(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout='State OFF\n')
        self.assertFalse(firewall_check.get_firewall_status())

    @patch('system_utils.os.name', 'posix')
    @patch('system_utils.subprocess.run')
    def test_get_firewall_status_linux_active(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout='Status: active\n')
        self.assertTrue(firewall_check.get_firewall_status())

    @patch('system_utils.os.name', 'posix')
    @patch('system_utils.subprocess.run')
    def test_get_firewall_status_linux_inactive(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout='inactive\n')
        self.assertFalse(firewall_check.get_firewall_status())


if __name__ == '__main__':
    unittest.main()

import unittest
from unittest.mock import patch, MagicMock

import os_version


class OSVersionTest(unittest.TestCase):
    @patch('os_version.sys.platform', 'win32')
    @patch('os_version.sys.getwindowsversion', create=True)
    def test_windows_7(self, mock_get):
        mock_get.return_value = MagicMock(major=6, minor=1)
        self.assertEqual(os_version.get_windows_version(), 'Windows 7')

    @patch('os_version.sys.platform', 'win32')
    @patch('os_version.sys.getwindowsversion', create=True)
    def test_windows_xp(self, mock_get):
        mock_get.return_value = MagicMock(major=5, minor=1)
        self.assertEqual(os_version.get_windows_version(), 'Windows XP')

    @patch('os_version.sys.platform', 'win32')
    @patch('os_version.sys.getwindowsversion', create=True)
    def test_windows_8(self, mock_get):
        mock_get.return_value = MagicMock(major=6, minor=2)
        self.assertEqual(os_version.get_windows_version(), 'Windows 8')

    @patch('os_version.sys.platform', 'linux')
    def test_non_windows(self):
        self.assertIsNone(os_version.get_windows_version())


if __name__ == '__main__':
    unittest.main()

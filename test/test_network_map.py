import json
import io
import sys
import unittest
from unittest.mock import patch

import network_map


class NetworkMapTest(unittest.TestCase):
    @patch('network_map.discover_hosts')
    def test_main_success(self, mock_discover):
        hosts = [{'ip': '1.2.3.4', 'mac': 'aa:bb', 'vendor': 'Vendor'}]
        mock_discover.return_value = hosts
        stdout = io.StringIO()
        stderr = io.StringIO()
        with patch('sys.argv', ['network_map.py']), \
             patch('sys.stdout', stdout), \
             patch('sys.stderr', stderr):
            code = network_map.main()
        self.assertEqual(code, 0)
        out_lines = stdout.getvalue().strip().splitlines()
        self.assertEqual(out_lines[0], json.dumps(hosts, ensure_ascii=False))
        self.assertEqual(out_lines[1], 'Host discovery succeeded')
        self.assertEqual(stderr.getvalue(), '')

    @patch('network_map.discover_hosts')
    def test_main_with_subnet(self, mock_discover):
        hosts = [{'ip': '1.2.3.4', 'mac': 'aa:bb', 'vendor': 'Vendor'}]
        mock_discover.return_value = hosts
        stdout = io.StringIO()
        stderr = io.StringIO()
        subnet = '10.0.0.0/24'
        with patch('sys.argv', ['network_map.py', subnet]), \
             patch('sys.stdout', stdout), \
             patch('sys.stderr', stderr):
            code = network_map.main()
        self.assertEqual(code, 0)
        mock_discover.assert_called_once_with(subnet)
        out_lines = stdout.getvalue().strip().splitlines()
        self.assertEqual(out_lines[0], json.dumps(hosts, ensure_ascii=False))
        self.assertEqual(out_lines[1], 'Host discovery succeeded')
        self.assertEqual(stderr.getvalue(), '')

    @patch('network_map.discover_hosts', side_effect=RuntimeError('boom'))
    def test_main_failure(self, mock_discover):
        stdout = io.StringIO()
        stderr = io.StringIO()
        with patch('sys.argv', ['network_map.py']), \
             patch('sys.stdout', stdout), \
             patch('sys.stderr', stderr):
            code = network_map.main()
        self.assertEqual(code, 1)
        self.assertEqual(stdout.getvalue(), '')
        self.assertIn('Host discovery failed: boom', stderr.getvalue().strip())


if __name__ == '__main__':
    unittest.main()

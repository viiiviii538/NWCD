import unittest
from unittest.mock import patch, MagicMock
import time
import socket
import network_utils

class DiscoverHostsSubnetTest(unittest.TestCase):
    @patch('network_utils.os.name', 'posix')
    @patch('network_utils.sys.platform', 'darwin')
    @patch('network_utils.subprocess.run')
    def test_get_subnet_darwin(self, mock_run):
        ifconfig_output = """
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
    inet 127.0.0.1 netmask 0xff000000
en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
    inet 192.168.2.5 netmask 0xffffff00 broadcast 192.168.2.255
"""
        mock_run.return_value = MagicMock(returncode=0, stdout=ifconfig_output)
        subnet = network_utils._get_subnet()
        self.assertEqual(subnet, '192.168.2.0/24')


class LookupVendorTimeoutTest(unittest.TestCase):
    def test_lookup_vendor_timeout(self):
        def side_effect(*args, **kwargs):
            self.assertIn('timeout', kwargs)
            time.sleep(0.1)
            raise socket.timeout()

        start = time.time()
        with patch('network_utils.urlopen', side_effect=side_effect):
            vendor = network_utils._lookup_vendor('00:11:22:33:44:55')
        elapsed = time.time() - start
        self.assertEqual(vendor, '')
        self.assertLess(elapsed, 1.0)

if __name__ == '__main__':
    unittest.main()

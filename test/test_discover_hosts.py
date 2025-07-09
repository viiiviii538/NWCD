import unittest
from unittest.mock import patch, MagicMock
import discover_hosts


class DiscoverHostsSubnetTest(unittest.TestCase):
    @patch('discover_hosts.os.name', 'posix')
    @patch('discover_hosts.sys.platform', 'darwin')
    @patch('discover_hosts.subprocess.run')
    def test_get_subnet_darwin(self, mock_run):
        ifconfig_output = """
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
    inet 127.0.0.1 netmask 0xff000000
en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
    inet 192.168.2.5 netmask 0xffffff00 broadcast 192.168.2.255
"""
        mock_run.return_value = MagicMock(returncode=0, stdout=ifconfig_output)
        subnet = discover_hosts._get_subnet()
        self.assertEqual(subnet, '192.168.2.0/24')


if __name__ == '__main__':
    unittest.main()

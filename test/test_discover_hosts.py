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


class RunNmapScanHostnameTest(unittest.TestCase):
    @patch('network_utils.shutil.which')
    @patch('subprocess.run')
    def test_hostname_resolution(self, mock_run, mock_which):
        xml = (
            "<nmaprun>"
            "<host><address addr='192.168.1.2' addrtype='ipv4'/>"
            "<hostnames><hostname name='host-nmap'/></hostnames></host>"
            "<host><address addr='192.168.1.3' addrtype='ipv4'/></host>"
            "<host><address addr='192.168.1.4' addrtype='ipv4'/></host>"
            "</nmaprun>"
        )

        def run_side_effect(cmd, capture_output=True, text=True, timeout=None):
            if cmd[0] == 'nmap':
                return MagicMock(returncode=0, stdout=xml)
            if cmd[0] == 'nbtscan':
                if cmd[-1] == '192.168.1.3':
                    return MagicMock(returncode=0, stdout='192.168.1.3\thost-nbt\n')
                return MagicMock(returncode=1, stdout='')
            if cmd[0] == 'avahi-resolve':
                return MagicMock(returncode=0, stdout='192.168.1.4 host-mdns.local\n')
            return MagicMock(returncode=1, stdout='')

        mock_run.side_effect = run_side_effect
        mock_which.return_value = '/usr/bin/mock'

        res = network_utils._run_nmap_scan('192.168.1.0/24')

        mock_run.assert_any_call(
            ['nmap', '-R', '-sn', '192.168.1.0/24', '-oX', '-'],
            capture_output=True,
            text=True,
            timeout=network_utils.SCAN_TIMEOUT,
        )
        self.assertEqual(res[0]['hostname'], 'host-nmap')
        self.assertEqual(res[1]['hostname'], 'host-nbt')
        self.assertEqual(res[2]['hostname'], 'host-mdns.local')

if __name__ == '__main__':
    unittest.main()

import unittest
from unittest.mock import patch, MagicMock
import time
import socket
import network_utils
import discover_hosts

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
    @patch('network_utils._lookup_vendor', return_value='')
    @patch('network_utils.shutil.which')
    @patch('subprocess.run')
    def test_hostname_resolution(self, mock_run, mock_which, _mock_lookup):
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


class RunNmapScanVendorTest(unittest.TestCase):
    @patch('network_utils._lookup_vendor', return_value='Vendor Inc')
    @patch('network_utils.shutil.which', return_value=None)
    @patch('subprocess.run')
    def test_vendor_lookup(self, mock_run, _mock_which, mock_lookup):
        xml = (
            "<nmaprun>"
            "<host><address addr='192.168.1.2' addrtype='ipv4'/>"
            "<address addr='AA:BB:CC:DD:EE:FF' addrtype='mac'/></host>"
            "</nmaprun>"
        )
        mock_run.return_value = MagicMock(returncode=0, stdout=xml)

        res = network_utils._run_nmap_scan('192.168.1.0/24')

        mock_lookup.assert_called_once_with('AA:BB:CC:DD:EE:FF')
        self.assertEqual(res[0]['vendor'], 'Vendor Inc')


class DiscoverHostsResultTest(unittest.TestCase):
    @patch('network_utils.Path.exists', return_value=False)
    @patch('network_utils.urlopen')
    @patch('discover_hosts._run_nmap_scan')
    def test_hostname_and_vendor_present(self, mock_scan, mock_urlopen, _mock_exists):
        mock_scan.return_value = [
            {
                'ip': '192.168.1.2',
                'mac': 'AA:BB:CC:DD:EE:FF',
                'vendor': '',
                'hostname': 'host-nmap',
            }
        ]
        mock_urlopen.return_value.__enter__.return_value.read.return_value = b'Vendor Inc'
        hosts = discover_hosts.discover_hosts('192.168.1.0/24')
        self.assertEqual(hosts[0]['hostname'], 'host-nmap')
        self.assertEqual(hosts[0]['vendor'], 'Vendor Inc')

if __name__ == '__main__':
    unittest.main()

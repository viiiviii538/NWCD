import unittest
from unittest.mock import patch
import lan_port_scan


class LanPortScanJsonTest(unittest.TestCase):
    @patch('lan_port_scan.run_scan')
    @patch('lan_port_scan._run_nmap_scan')
    def test_basic_json(self, mock_nmap, mock_scan):
        mock_nmap.return_value = [{'ip': '192.168.1.2', 'mac': 'aa', 'vendor': 'X'}]
        mock_scan.return_value = {'os': 'Windows', 'ports': [{'port': '22', 'state': 'open', 'service': 'ssh'}]}
        res = lan_port_scan.scan_hosts('192.168.1.0/24', ['22'])
        self.assertIsInstance(res, list)
        self.assertEqual(res[0]['ip'], '192.168.1.2')
        self.assertIn('ports', res[0])
        self.assertEqual(res[0]['ports'][0]['port'], '22')
        self.assertEqual(res[0]['os'], 'Windows')

    @patch('lan_port_scan.run_scan')
    @patch('lan_port_scan._lookup_vendor', return_value='')
    @patch('lan_port_scan._run_nmap_scan')
    def test_fallback_nmap(self, mock_nmap, mock_lookup, mock_scan):
        mock_nmap.return_value = [{'ip': '10.0.0.5', 'mac': '', 'vendor': ''}]
        mock_scan.return_value = {'os': '', 'ports': []}
        res = lan_port_scan.scan_hosts('10.0.0.0/24', ['80'])
        self.assertEqual(res[0]['ip'], '10.0.0.5')
        self.assertEqual(res[0]['ports'], [])

@patch('lan_port_scan.run_scan')
@patch('lan_port_scan._run_nmap_scan')
def test_ipv6_hosts(mock_nmap, mock_scan):
    mock_nmap.return_value = [{'ip': 'fe80::1', 'mac': 'aa', 'vendor': 'X'}]
    mock_scan.return_value = {'os': '', 'ports': []}
    res = lan_port_scan.scan_hosts('fe80::/64', ['80'])
    mock_scan.assert_called_with(
        'fe80::1', ['80'], service=False, os_detect=False, scripts=None
    )
    assert res[0]['ip'] == 'fe80::1'


class FakeFuture:
    def __init__(self, fn, *args, **kwargs):
        self.fn = fn
        self.args = args
        self.kwargs = kwargs

    def result(self):
        return self.fn(*self.args, **self.kwargs)


class FakeExecutor:
    instance = None

    def __init__(self, *args, **kwargs):
        FakeExecutor.instance = self
        self.submitted = []

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        pass

    def submit(self, fn, *args, **kwargs):
        self.submitted.append((fn, args, kwargs))
        return FakeFuture(fn, *args, **kwargs)


def _fake_as_completed(fs):
    for f in fs:
        yield f


class LanPortScanConcurrencyTest(unittest.TestCase):
    @patch('lan_port_scan.as_completed', _fake_as_completed)
    @patch('lan_port_scan.ThreadPoolExecutor', FakeExecutor)
    @patch('lan_port_scan.gather_hosts')
    def test_concurrent_execution(self, mock_gather):
        mock_gather.return_value = [
            {'ip': '1.1.1.1', 'mac': '', 'vendor': ''},
            {'ip': '1.1.1.2', 'mac': '', 'vendor': ''},
        ]

        call_counts = []

        def side_effect(*args, **kwargs):
            call_counts.append(len(FakeExecutor.instance.submitted))
            return {"os": "", "ports": []}

        with patch('lan_port_scan.run_scan', side_effect=side_effect) as mock_run:
            lan_port_scan.scan_hosts('1.1.1.0/24', ['80'])
            self.assertEqual(mock_run.call_count, 2)
            self.assertEqual(len(FakeExecutor.instance.submitted), 2)
            self.assertTrue(all(c == 2 for c in call_counts))

if __name__ == '__main__':
    unittest.main()

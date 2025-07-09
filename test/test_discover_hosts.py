import unittest
from unittest.mock import patch, MagicMock
import discover_hosts

class LookupVendorCacheTest(unittest.TestCase):
    def setUp(self):
        discover_hosts._VENDOR_CACHE.clear()

    @patch('pathlib.Path.exists', return_value=False)
    @patch('discover_hosts.urlopen')
    def test_lookup_vendor_caches_result(self, mock_urlopen, mock_exists):
        resp = MagicMock()
        resp.read.return_value = b'MyVendor'
        mock_urlopen.return_value.__enter__.return_value = resp

        vendor1 = discover_hosts._lookup_vendor('aa:bb:cc:dd:ee:ff')
        vendor2 = discover_hosts._lookup_vendor('AA:BB:CC:11:22:33')

        self.assertEqual(vendor1, 'MyVendor')
        self.assertEqual(vendor2, 'MyVendor')
        mock_urlopen.assert_called_once()

if __name__ == '__main__':
    unittest.main()

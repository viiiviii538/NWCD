import unittest
from unittest.mock import patch, MagicMock
import external_ip_report


class ExternalIPReportTest(unittest.TestCase):
    def test_classify_port_encrypted(self):
        self.assertEqual(external_ip_report.classify_port(443), "\u6697\u53f7\u5316")

    def test_classify_port_unencrypted(self):
        self.assertEqual(external_ip_report.classify_port(80), "\u975e\u6697\u53f7\u5316")

    def test_classify_port_unknown(self):
        self.assertEqual(external_ip_report.classify_port(12345), "\u4e0d\u660e")

    def test_reverse_dns_success(self):
        with patch('socket.gethostbyaddr') as mock_get:
            mock_get.return_value = ('example.com', [], ['93.184.216.34'])
            self.assertEqual(external_ip_report.reverse_dns('93.184.216.34'), 'example.com')

    def test_reverse_dns_failure(self):
        with patch('socket.gethostbyaddr', side_effect=Exception()):
            self.assertEqual(external_ip_report.reverse_dns('8.8.8.8'), '')

    def test_geoip_country_reader_none(self):
        self.assertEqual(external_ip_report.geoip_country(None, '1.1.1.1'), '')

    def test_geoip_country_success(self):
        reader = MagicMock()
        resp = MagicMock()
        resp.country.iso_code = 'US'
        reader.country.return_value = resp
        self.assertEqual(external_ip_report.geoip_country(reader, '1.1.1.1'), 'US')
        reader.country.assert_called_once_with('1.1.1.1')

    def test_geoip_country_exception(self):
        reader = MagicMock()
        reader.country.side_effect = Exception()
        self.assertEqual(external_ip_report.geoip_country(reader, '1.1.1.1'), '')


if __name__ == '__main__':
    unittest.main()

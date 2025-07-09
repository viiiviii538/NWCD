import unittest
from unittest.mock import patch, MagicMock
import external_ip_report
import json

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

    @patch('external_ip_report.get_external_connections')
    @patch('external_ip_report.reverse_dns', return_value='dns.google')
    def test_json_output(self, mock_rdns, mock_get):
        mock_get.return_value = [('8.8.8.8', 80)]
        with patch('external_ip_report.geoip2', None):
            with patch('sys.argv', ['external_ip_report.py', '--json']):
                with patch('sys.stdout') as mock_out:
                    external_ip_report.main()
                    output = ''.join(call.args[0] for call in mock_out.write.call_args_list)
        data = json.loads(output)
        self.assertEqual(data[0]['dest'], 'dns.google')
        self.assertEqual(data[0]['protocol'], 'HTTP')
        self.assertEqual(data[0]['encryption'], '\u975e\u6697\u53f7\u5316')
        self.assertEqual(data[0]['state'], '危険')
        self.assertEqual(data[0]['comment'], '平文通信のため情報漏洩のリスクがあります')

if __name__ == '__main__':
    unittest.main()

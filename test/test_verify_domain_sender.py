import unittest
from unittest.mock import patch
import json

import verify_domain_sender

class VerifyDomainSenderTest(unittest.TestCase):
    @patch('dns_records.get_spf_record')
    @patch('dns_records.get_dkim_record')
    @patch('dns_records.get_dmarc_record')
    def test_all_records_present(self, mock_dmarc, mock_dkim, mock_spf):
        mock_spf.return_value = 'v=spf1 +mx -all'
        mock_dkim.return_value = 'v=DKIM1; k=rsa; p=abcd'
        mock_dmarc.return_value = 'v=DMARC1; p=none'
        res = verify_domain_sender.check_domain('example.com')
        self.assertEqual(res['status'], 'safe')
        self.assertEqual(res['spf'], 'v=spf1 +mx -all')
        self.assertEqual(res['dkim'], 'v=DKIM1; k=rsa; p=abcd')
        self.assertEqual(res['dmarc'], 'v=DMARC1; p=none')

    @patch('dns_records.get_spf_record', return_value='')
    @patch('dns_records.get_dkim_record', return_value='')
    @patch('dns_records.get_dmarc_record', return_value='')
    def test_missing_records(self, mock_dmarc, mock_dkim, mock_spf):
        res = verify_domain_sender.check_domain('example.com')
        self.assertEqual(res['status'], 'danger')
        self.assertEqual(res['comment'], 'No SPF record found')

    @patch('dns_records.get_spf_record', return_value='v=spf1 +mx -all')
    @patch('dns_records.get_dkim_record', return_value='v=DKIM1')
    @patch('dns_records.get_dmarc_record', return_value='v=DMARC1')
    @patch('verify_domain_sender.lookup_spf', return_value='')
    def test_cli_multiple_domains(self, *_mocks):
        with patch('sys.argv', ['verify_domain_sender.py', '--domains', 'example.com', 'test.com']):
            with patch('sys.stdout') as mock_out:
                verify_domain_sender.main()
                output = ''.join(call.args[0] for call in mock_out.write.call_args_list)

        entries = [json.loads(line) for line in output.splitlines() if line.strip()]
        self.assertEqual(len(entries), 2)
        for ent in entries:
            self.assertEqual(ent['status'], 'safe')
            self.assertEqual(ent['spf'], 'v=spf1 +mx -all')
            self.assertEqual(ent['dkim'], 'v=DKIM1')
            self.assertEqual(ent['dmarc'], 'v=DMARC1')


if __name__ == '__main__':
    unittest.main()

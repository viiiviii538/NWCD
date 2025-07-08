import unittest
from unittest.mock import patch

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


if __name__ == '__main__':
    unittest.main()

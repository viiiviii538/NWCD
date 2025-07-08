import unittest
import json
import subprocess
from dns_records import get_spf_record, get_dkim_record, get_dmarc_record

class DnsRecordFileTest(unittest.TestCase):
    def setUp(self):
        self.zone = 'test/sample_zone.txt'

    def test_spf_from_file(self):
        rec = get_spf_record('example.com', records_file=self.zone)
        self.assertEqual(rec, 'v=spf1 +mx -all')

    def test_dkim_from_file(self):
        rec = get_dkim_record('example.com', selector='default', records_file=self.zone)
        self.assertEqual(rec, 'v=DKIM1; k=rsa; p=abcd')

    def test_dmarc_from_file(self):
        rec = get_dmarc_record('example.com', records_file=self.zone)
        self.assertEqual(rec, 'v=DMARC1; p=none')

    def test_cli_zone_file(self):
        proc = subprocess.run(
            ['python', 'dns_records.py', 'example.com', '--zone-file', self.zone],
            capture_output=True,
            text=True,
            check=True,
        )
        data = json.loads(proc.stdout)
        self.assertEqual(data['spf'], 'v=spf1 +mx -all')
        self.assertEqual(data['dkim'], 'v=DKIM1; k=rsa; p=abcd')
        self.assertEqual(data['dmarc'], 'v=DMARC1; p=none')

if __name__ == '__main__':
    unittest.main()

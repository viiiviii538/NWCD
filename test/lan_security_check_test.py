import unittest
from unittest.mock import patch
from lan_security_check import (
    parse_arp_table,
    parse_dhcp_output,
    parse_upnp_output,
    parse_netbios_output,
    parse_smb_protocol_output,
    check_external_comm,
)


class LanSecurityParseTest(unittest.TestCase):
    def test_parse_arp_table_duplicate(self):
        sample = """Interface: 192.168.1.2 --- 0x3
  Internet Address      Physical Address      Type
  192.168.1.1           11-22-33-44-55-66     dynamic
  192.168.1.1           22-33-44-55-66-77     dynamic
"""
        table = parse_arp_table(sample)
        self.assertIn("192.168.1.1", table)
        self.assertEqual(len(set(table["192.168.1.1"])), 2)

    def test_parse_dhcp_output_multiple(self):
        sample = """| broadcast-dhcp-discover:\n|   Response 1 of 2:\n|     DHCP Message Type: DHCP Offer\n|     Server Identifier: 192.168.1.1\n|   Response 2 of 2:\n|     DHCP Message Type: DHCP Offer\n|     Server Identifier: 192.168.1.254\n"""
        count = parse_dhcp_output(sample)
        self.assertEqual(count, 2)

    def test_parse_upnp_output_found(self):
        sample = "Found UPnP devices: desc: http://192.168.1.1:80/desc.xml"
        self.assertTrue(parse_upnp_output(sample))

    def test_parse_netbios_output(self):
        sample = "Host: 192.168.1.5 (192.168.1.5) Ports: 445/open/tcp//microsoft-ds///"
        hosts = parse_netbios_output(sample)
        self.assertIn("192.168.1.5", hosts)

    def test_parse_smb_protocol_output(self):
        sample = "| smb-protocols:\n|   dialects:\n|     NT LM 0.12 (SMBv1) [dangerous!]\n"
        self.assertTrue(parse_smb_protocol_output(sample))


class ExternalCommCountTest(unittest.TestCase):
    @patch('lan_security_check.geoip2', None)
    @patch('lan_security_check.geoip_country')
    @patch('lan_security_check.get_external_connections')
    def test_country_counts(self, mock_get_conns, mock_geoip_country, _):
        mock_get_conns.return_value = [
            ('1.1.1.1', 80),
            ('2.2.2.2', 443),
            ('3.3.3.3', 22),
        ]

        def side_effect(reader, ip):
            return {
                '1.1.1.1': 'US',
                '2.2.2.2': 'CN',
                '3.3.3.3': 'CN',
            }[ip]

        mock_geoip_country.side_effect = side_effect

        res = check_external_comm()
        self.assertEqual(res['country_counts'], {'US': 1, 'CN': 2})
        self.assertEqual(res['status'], 'warning')
        self.assertEqual(len(res['connections']), 2)


if __name__ == "__main__":
    unittest.main()

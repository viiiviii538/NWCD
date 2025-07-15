import pytest
from security_report import parse_args


def test_parse_args_utm_active_true():
    argv = ['security_report.py', '1.2.3.4', '80,443', 'valid', 'true', 'JP', 'true']
    ip, ports, ssl_status, spf_valid, geoip, utm_active = parse_args(argv)
    assert ip == '1.2.3.4'
    assert ports == ['80', '443']
    assert ssl_status == 'valid'
    assert spf_valid is True
    assert geoip == 'JP'
    assert utm_active is True

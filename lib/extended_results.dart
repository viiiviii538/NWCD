class SslCheck {
  final String domain;
  final String issuer;
  final String expiry;
  final String status;
  final String comment;

  const SslCheck(
      {required this.domain,
      required this.issuer,
      required this.expiry,
      required this.status,
      required this.comment});
}

class DomainAuthCheck {
  final String domain;
  final bool spf;
  final bool dkim;
  final bool dmarc;
  final String status;
  final String comment;

  const DomainAuthCheck(
      {required this.domain,
      required this.spf,
      required this.dkim,
      required this.dmarc,
      required this.status,
      required this.comment});
}

class GeoIpStat {
  final String country;
  final int count;
  final String status;

  const GeoIpStat({required this.country, required this.count, required this.status});
}

class LanDeviceRisk {
  final String ip;
  final String mac;
  final String vendor;
  final String os;
  final String name;
  final String status;
  final String comment;

  const LanDeviceRisk(
      {required this.ip,
      required this.mac,
      required this.vendor,
      this.os = '',
      required this.name,
      required this.status,
      required this.comment});
}

class ExternalCommInfo {
  final String domain;
  final String protocol;
  final String encryption;
  final String status;
  final String comment;

  const ExternalCommInfo(
      {required this.domain,
      required this.protocol,
      required this.encryption,
      required this.status,
      required this.comment});
}

class DefenseFeatureStatus {
  final String feature;
  final String status;
  final String comment;

  const DefenseFeatureStatus(
      {required this.feature, required this.status, required this.comment});
}

const dangerCountries = {'CN', 'RU', 'KP'};
const safeCountries = {'JP', 'US', 'GB', 'DE', 'FR', 'CA', 'AU'};

String judgeGeoipStatus(String country) {
  final code = country.toUpperCase();
  if (dangerCountries.contains(code)) return 'danger';
  if (safeCountries.contains(code)) return 'safe';
  return 'warning';
}

class GeoipEntry {
  final String ip;
  final String domain;
  final String country;

  GeoipEntry(this.ip, this.domain, this.country);

  factory GeoipEntry.fromJson(Map<String, dynamic> json) {
    return GeoipEntry(
      json['ip']?.toString() ?? '',
      json['domain']?.toString() ?? '',
      json['country']?.toString() ?? '',
    );
  }

  String get status => judgeGeoipStatus(country);

  String get comment {
    switch (status) {
      case 'danger':
        return '危険国との通信';
      case 'warning':
        return '未知の国への通信';
      default:
        return '';
    }
  }
}

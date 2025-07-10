/// Ports used when no preset is specified.
const List<int> defaultPortList = [
  21, 22, 23, 25, 53, 80, 110, 143,
  443, 445, 3306, 3389,
];

/// Minimal set of ports for a quick scan.
const List<int> quickPorts = [80, 443];

/// Expanded set of ports for a thorough scan.
const List<int> fullPorts = [
  21,
  22,
  23,
  25,
  53,
  80,
  110,
  143,
  443,
  445,
  3306,
  3389,
  5900,
  8080,
];

/// Notes for ports that are often targeted by attackers.
///
/// If a scanned device has any of these ports open, the corresponding
/// description can be shown in the UI as a warning message.
const Map<int, String> dangerPortNotes = {
  3389: 'RDP ポートが開いていると乗っ取りの恐れがあります',
  445: 'SMB ポートは脆弱性悪用の標的となりやすいです',
  23: 'Telnet は暗号化されないため危険です',
};

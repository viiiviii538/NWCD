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

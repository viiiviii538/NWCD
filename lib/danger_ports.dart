/// Warning messages for high-risk ports.
///
/// The keys are port numbers and the values explain why the port is
/// considered dangerous when open.
const Map<int, String> dangerPortNotes = {
  3389: 'RDP ポートが開いていると乗っ取りの恐れがあります',
  445: 'SMB ポートは脆弱性悪用の標的となりやすいです',
  23: 'Telnet は暗号化されないため危険です',
};

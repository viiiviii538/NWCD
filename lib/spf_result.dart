class SpfResult {
  final String domain;
  final String record;
  final String status; // safe, warning, danger
  final String comment;
  final bool dkimValid;
  final bool dmarcValid;

  const SpfResult(
    this.domain,
    this.record,
    this.status,
    this.comment, {
    this.dkimValid = false,
    this.dmarcValid = false,
  });
}

class SpfResult {
  final String domain;
  final String record;
  final String status; // safe, warning, danger
  final String comment;

  const SpfResult(this.domain, this.record, this.status, this.comment);
}

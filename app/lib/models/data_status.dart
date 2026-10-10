/// Explicit availability states. Unknown results are labelled, never invented.
enum DataStatus {
  available('available', 'Available'),
  preliminary('preliminary', 'Preliminary'),
  notAvailable('not_available', 'Not available'),
  notEvaluated('not_evaluated', 'Not evaluated'),
  error('error', 'Error');

  const DataStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Parses an API value. Unknown values map to [notAvailable] rather than
  /// pretending that a result exists.
  static DataStatus fromApi(String? value) {
    for (final s in DataStatus.values) {
      if (s.apiValue == value) return s;
    }
    return DataStatus.notAvailable;
  }

  /// True when there is something to show (even if preliminary).
  bool get hasResult =>
      this == DataStatus.available || this == DataStatus.preliminary;
}

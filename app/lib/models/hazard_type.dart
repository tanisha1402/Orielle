/// The two initial hazard modules.
enum HazardType {
  floodExpansion('flood_expansion', 'Flood expansion', 'Floods'),
  slopeDeformation('slope_deformation', 'Slope deformation', 'Slopes');

  const HazardType(this.apiValue, this.label, this.shortLabel);

  /// Value used by the API (`?hazard=flood_expansion`).
  final String apiValue;
  final String label;
  final String shortLabel;

  static HazardType? tryParse(String? value) {
    for (final h in HazardType.values) {
      if (h.apiValue == value) return h;
    }
    return null;
  }
}

import '../../models/analysis_result.dart';
import '../../models/hazard_zone.dart';

/// The selected zone if it belongs to [analysis], else the top-ranked zone.
HazardZone? effectiveZone(AnalysisResult analysis, String? selectedId) {
  final selected = analysis.zoneById(selectedId);
  if (selected != null) return selected;
  if (analysis.zones.isEmpty) return null;
  return analysis.zonesByRank.first;
}

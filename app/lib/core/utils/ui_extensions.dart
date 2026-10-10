import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../models/data_status.dart';
import '../../models/hazard_type.dart';
import '../../models/hazard_zone.dart';
import '../../models/map_layer.dart';

extension HazardTypeUi on HazardType {
  IconData get icon => this == HazardType.floodExpansion
      ? Icons.water_outlined
      : Icons.terrain_outlined;

  Color get color =>
      this == HazardType.floodExpansion ? AppColors.flood : AppColors.slope;
}

extension DataStatusUi on DataStatus {
  Color get color {
    switch (this) {
      case DataStatus.available:
        return AppColors.green400;
      case DataStatus.preliminary:
        return AppColors.warning;
      case DataStatus.notAvailable:
        return AppColors.textSecondary;
      case DataStatus.notEvaluated:
        return AppColors.info;
      case DataStatus.error:
        return AppColors.danger;
    }
  }

  IconData get icon {
    switch (this) {
      case DataStatus.available:
        return Icons.check_circle_outline;
      case DataStatus.preliminary:
        return Icons.hourglass_bottom;
      case DataStatus.notAvailable:
        return Icons.do_not_disturb_alt_outlined;
      case DataStatus.notEvaluated:
        return Icons.rule;
      case DataStatus.error:
        return Icons.error_outline;
    }
  }
}

extension LayerClassificationUi on LayerClassification {
  Color get color {
    switch (this) {
      case LayerClassification.observed:
        return AppColors.observed;
      case LayerClassification.derived:
        return AppColors.derived;
      case LayerClassification.predicted:
        return AppColors.predicted;
      case LayerClassification.context:
        return AppColors.context;
    }
  }
}

extension ZoneBasisUi on ZoneBasis {
  Color get color =>
      this == ZoneBasis.observed ? AppColors.observed : AppColors.predicted;
}

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../models/data_status.dart';
import '../../models/hazard_zone.dart';
import '../../models/map_layer.dart';
import '../utils/color_utils.dart';
import '../utils/ui_extensions.dart';

/// Rounded outlined tag used by all chips below.
class Tag extends StatelessWidget {
  const Tag({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.semanticsLabel,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: withFraction(color, 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: withFraction(color, 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Availability state of an analysis, prediction or validation.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.prefix});

  final DataStatus status;

  /// Optional prefix such as `Prediction`.
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    final text = prefix == null ? status.label : '$prefix: ${status.label}';
    return Tag(label: text, color: status.color, icon: status.icon);
  }
}

/// Observed / Derived / Predicted / Context.
class ClassificationChip extends StatelessWidget {
  const ClassificationChip(this.classification, {super.key});

  final LayerClassification classification;

  @override
  Widget build(BuildContext context) =>
      Tag(label: classification.label, color: classification.color);
}

/// Observed vs predicted zone basis.
class BasisChip extends StatelessWidget {
  const BasisChip(this.basis, {super.key});

  final ZoneBasis basis;

  @override
  Widget build(BuildContext context) => Tag(
        label: basis.label,
        color: basis.color,
        icon: basis == ZoneBasis.observed
            ? Icons.visibility_outlined
            : Icons.auto_graph,
      );
}

/// Marks demonstration records. Shown wherever sample data is displayed.
class SampleDataBadge extends StatelessWidget {
  const SampleDataBadge({super.key});

  @override
  Widget build(BuildContext context) => const Tag(
        label: 'SAMPLE DATA',
        color: AppColors.warning,
        icon: Icons.science_outlined,
        semanticsLabel: 'Sample data, not real measurements',
      );
}

/// Wide notice explaining that figures are illustrative.
class SampleDataBanner extends StatelessWidget {
  const SampleDataBanner({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: withFraction(AppColors.warning, 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: withFraction(AppColors.warning, 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.science_outlined,
              size: 20, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message ??
                  'SAMPLE DATA: every number, date and shape in this view is '
                      'illustrative. None of it is a satellite-derived '
                      'measurement or a verified result.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

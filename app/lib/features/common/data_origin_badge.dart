import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/widgets/badges.dart';
import '../../state/providers.dart';

/// Shows **SAMPLE DATA** for demonstration regions and **REAL DATA** for
/// regions backed by real historical records, so the two are never confused.
/// While the region is loading it falls back to the sample label.
class DataOriginBadge extends ConsumerWidget {
  const DataOriginBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = ref.watch(effectiveAreaProvider).valueOrNull;
    if (area != null && !area.isSample) {
      return const Tag(
        label: 'REAL DATA',
        color: AppColors.green400,
        icon: Icons.verified_outlined,
        semanticsLabel: 'Real historical data, not sample data',
      );
    }
    return const SampleDataBadge();
  }
}

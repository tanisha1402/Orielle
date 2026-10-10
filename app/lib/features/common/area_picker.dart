import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/ui_extensions.dart';
import '../../core/widgets/badges.dart';
import '../../models/analysis_result.dart';
import '../../models/hazard_type.dart';
import '../../models/study_area.dart';
import '../../state/providers.dart';

/// Button showing the selected region; opens a picker sheet.
class AreaPickerButton extends ConsumerWidget {
  const AreaPickerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areas = ref.watch(areasProvider);
    final selected = ref.watch(effectiveAreaProvider).valueOrNull;
    return areas.when(
      loading: () => const OutlinedButton(
        onPressed: null,
        child: Text('Loading regions...'),
      ),
      error: (Object e, StackTrace s) => OutlinedButton.icon(
        onPressed: () => ref.invalidate(areasProvider),
        icon: const Icon(Icons.refresh),
        label: const Text('Regions unavailable - retry'),
      ),
      data: (List<StudyArea> list) => OutlinedButton.icon(
        key: const Key('area-picker'),
        onPressed: list.isEmpty ? null : () => showAreaPicker(context, list),
        icon: const Icon(Icons.place_outlined, size: 20),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                selected?.name ?? 'Select region',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing all study areas.
Future<void> showAreaPicker(BuildContext context, List<StudyArea> areas) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.navy800,
    builder: (BuildContext sheetContext) {
      return Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          final summaries =
              ref.watch(analysisSummariesProvider).valueOrNull ??
                  const <AnalysisSummary>[];
          final selectedId = ref.watch(effectiveAreaProvider).valueOrNull?.id;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Choose a region',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  for (final area in areas)
                    ListTile(
                      key: Key('area-${area.id}'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Icon(
                        area.supportedHazards.isEmpty
                            ? Icons.place_outlined
                            : area.supportedHazards.first.icon,
                        color: area.supportedHazards.isEmpty
                            ? AppColors.textSecondary
                            : area.supportedHazards.first.color,
                      ),
                      title: Text(area.name),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: <Widget>[
                            for (final h in area.supportedHazards)
                              ..._statusFor(summaries, area, h),
                            if (area.isSample) const SampleDataBadge(),
                          ],
                        ),
                      ),
                      trailing: area.id == selectedId
                          ? const Icon(Icons.check, color: AppColors.green400)
                          : null,
                      onTap: () {
                        ref.read(selectionProvider.notifier).selectArea(area);
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

List<Widget> _statusFor(
  List<AnalysisSummary> summaries,
  StudyArea area,
  HazardType hazard,
) {
  final label = Text(
    hazard.shortLabel,
    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
  );
  for (final s in summaries) {
    if (s.studyAreaId == area.id && s.hazard == hazard) {
      return <Widget>[label, StatusChip(s.status)];
    }
  }
  return <Widget>[label];
}

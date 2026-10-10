import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/ui_extensions.dart';
import '../../models/hazard_type.dart';
import '../../models/study_area.dart';
import '../../state/providers.dart';
import 'area_picker.dart';

/// Flood / slope switch.
class HazardSelector extends ConsumerWidget {
  const HazardSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hazard = ref.watch(currentHazardProvider);
    return SegmentedButton<HazardType>(
      key: const Key('hazard-selector'),
      showSelectedIcon: false,
      segments: <ButtonSegment<HazardType>>[
        for (final h in HazardType.values)
          ButtonSegment<HazardType>(
            value: h,
            icon: Icon(h.icon, size: 18),
            label: Text(h.shortLabel),
          ),
      ],
      selected: <HazardType>{hazard},
      onSelectionChanged: (Set<HazardType> value) {
        final areas = ref.read(areasProvider).valueOrNull ?? const <StudyArea>[];
        ref.read(selectionProvider.notifier).selectHazard(value.first, areas);
      },
    );
  }
}

/// Region + hazard controls shared by Explore, Risk Analysis and Impact.
class ScopeBar extends StatelessWidget {
  const ScopeBar({super.key, this.padding = const EdgeInsets.all(16)});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          if (c.maxWidth >= 620) {
            return Row(
              children: const <Widget>[
                Flexible(child: AreaPickerButton()),
                SizedBox(width: 12),
                HazardSelector(),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const <Widget>[
              AreaPickerButton(),
              SizedBox(height: 8),
              HazardSelector(),
            ],
          );
        },
      ),
    );
  }
}

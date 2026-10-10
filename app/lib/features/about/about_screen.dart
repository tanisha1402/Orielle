import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../core/constants/app_config.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/panels.dart';
import '../../models/data_status.dart';
import '../../models/map_layer.dart';

/// "About this data": explains sample data, statuses and how to read results.
/// Opened with `context.push('/about')`, so it has a real back button.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('About this data'),
      ),
      body: ContentWidth(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const SampleDataBanner(),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Why everything is labelled SAMPLE',
              child: Text(
                AppConfig.useMockData
                    ? 'This build runs on a built-in demonstration dataset. '
                        'Numbers, dates, shapes and infrastructure counts are '
                        'illustrative so the interface can be reviewed before '
                        'the research pipeline delivers verified outputs. '
                        'They are not satellite-derived measurements. Regions '
                        'marked REAL DATA (August 2024 floods) use published '
                        'historical records instead; their sources are listed '
                        'under Data quality.'
                    : 'This build is configured to use a backend '
                        '(${AppConfig.apiBaseUrl.isEmpty ? 'URL not set' : AppConfig.apiBaseUrl}). '
                        'Values shown come from that service.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Four things that are kept separate',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _row(context, const ClassificationChip(LayerClassification.observed),
                      'What the satellite data show on specific dates.'),
                  _row(context, const ClassificationChip(LayerClassification.derived),
                      'Change calculated between observations. A change '
                      'between dates does not prove future expansion.'),
                  _row(context, const ClassificationChip(LayerClassification.predicted),
                      'Model estimates. Shown only with their status and '
                      'limits. Deformation does not prove an imminent landslide.'),
                  _row(context, const ClassificationChip(LayerClassification.context),
                      'Supporting layers such as terrain and infrastructure. '
                      'Exposure does not prove damage.'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Status labels',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _row(context, const StatusChip(DataStatus.available),
                      'A result exists.'),
                  _row(context, const StatusChip(DataStatus.preliminary),
                      'A result exists but is not validated.'),
                  _row(context, const StatusChip(DataStatus.notAvailable),
                      'Nothing has been produced. Not the same as "safe".'),
                  _row(context, const StatusChip(DataStatus.notEvaluated),
                      'Not tested against independent data; not a pass.'),
                  _row(context, const StatusChip(DataStatus.error),
                      'Processing or loading failed.'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Basemap',
              child: Text(
                'The online basemap uses a tile provider configured at build time '
                '(default: OpenStreetMap, attribution shown on the map). If '
                'tiles cannot load, switch to the offline schematic basemap '
                'from the map toolbar; overlays keep working.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${AppConfig.appName} - ${AppConfig.tagline}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Widget chip, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 4,
        children: <Widget>[
          chip,
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

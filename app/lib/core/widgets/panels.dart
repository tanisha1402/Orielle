import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../errors/app_exception.dart';
import '../utils/color_utils.dart';

/// Centres page content and caps its width on wide screens.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 960});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Standard analytical card.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    this.accent,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  /// Optional left accent colour (e.g. observed vs predicted).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy700,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navy600),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          if (accent != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: accent),
            ),
          Padding(
            padding: padding,
            child: Padding(
              padding: EdgeInsets.only(left: accent != null ? 6 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (title != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(title!, style: theme.textTheme.titleMedium),
                              if (subtitle != null) ...<Widget>[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (trailing != null) ...<Widget>[
                          const SizedBox(width: 8),
                          trailing!,
                        ],
                      ],
                    ),
                  if (title != null) const SizedBox(height: 12),
                  child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled measurement. `null` values render as "Not available".
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? caption;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navy600),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.metricValue.copyWith(
              fontSize: value.length > 14 ? 16 : 22,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(caption!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// Bulleted list of short statements.
class BulletList extends StatelessWidget {
  const BulletList(this.items, {super.key, this.icon});

  final List<String> items;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: icon != null
                      ? Icon(icon, size: 16, color: AppColors.textSecondary)
                      : const Text('\u2022'),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(item, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Explains that something is unavailable and why. Used for missing data,
/// missing predictions and unsupported layers.
class UnavailablePanel extends StatelessWidget {
  const UnavailablePanel({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.do_not_disturb_alt_outlined,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 20),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.navy600),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppColors.textSecondary, size: compact ? 22 : 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(message,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary)),
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingPanel extends StatelessWidget {
  const LoadingPanel({super.key, this.label = 'Loading...'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 14),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final exception = AppException.wrap(error);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: withFraction(AppColors.danger, 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: withFraction(AppColors.danger, 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.error_outline, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(exception.title,
                          style: theme.textTheme.titleSmall),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(exception.message, style: theme.textTheme.bodyMedium),
                if (onRetry != null) ...<Widget>[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders an [AsyncValue] with consistent loading and error states.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loadingLabel = 'Loading...',
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => LoadingPanel(label: loadingLabel),
      error: (Object e, StackTrace s) => ErrorPanel(error: e, onRetry: onRetry),
    );
  }
}

/// Lays out equally sized tiles in as many columns as fit.
class TileWrap extends StatelessWidget {
  const TileWrap({
    super.key,
    required this.children,
    this.minTileWidth = 150,
    this.spacing = 8,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final width = c.maxWidth.isFinite ? c.maxWidth : minTileWidth * 3;
        var columns = ((width + spacing) / (minTileWidth + spacing)).floor();
        if (columns < 1) columns = 1;
        if (columns > children.length) columns = children.length;
        final tileWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final child in children) SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}

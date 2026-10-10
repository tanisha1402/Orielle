import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_config.dart';
import 'theme/app_colors.dart';

class _Destination {
  const _Destination(this.key, this.label, this.shortLabel, this.icon, this.selectedIcon);

  final String key;
  final String label;
  final String shortLabel;
  final IconData icon;
  final IconData selectedIcon;
}

const List<_Destination> _destinations = <_Destination>[
  _Destination('home', 'Home', 'Home', Icons.public_outlined, Icons.public),
  _Destination('explore', 'Explore', 'Explore', Icons.map_outlined, Icons.map),
  _Destination('risk', 'Risk Analysis', 'Risk', Icons.insights_outlined, Icons.insights),
  _Destination('impact', 'Impact', 'Impact', Icons.home_work_outlined, Icons.home_work),
  _Destination('ask', 'Ask Earth', 'Ask Earth', Icons.forum_outlined, Icons.forum),
];

/// Responsive navigation frame: bottom bar on phones, rail on wide screens.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const double railBreakpoint = 840;
  static const double extendedRailBreakpoint = 1200;

  void _select(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final wide = constraints.maxWidth >= railBreakpoint;
        if (wide) {
          final extended = constraints.maxWidth >= extendedRailBreakpoint;
          return Scaffold(
            body: Row(
              children: <Widget>[
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _select,
                  extended: extended,
                  labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: _BrandMark(),
                  ),
                  destinations: <NavigationRailDestination>[
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _select,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: <Widget>[
              for (final d in _destinations)
                NavigationDestination(
                  key: Key('nav-${d.key}'),
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.shortLabel,
                  tooltip: d.label,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppConfig.appName,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[AppColors.teal700, AppColors.teal400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.public, color: AppColors.white),
      ),
    );
  }
}

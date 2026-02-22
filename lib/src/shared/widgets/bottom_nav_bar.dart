import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tranzfort/l10n/app_localizations.dart';

class BottomNavBar extends StatelessWidget {
  final String currentRole;

  const BottomNavBar({super.key, required this.currentRole});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = currentRole == 'supplier'
        ? _getSupplierItems(l10n)
        : _getTruckerItems(l10n);
    final currentPath = GoRouterState.of(context).matchedLocation;
    final currentIndex = _getActiveIndex(items, currentPath);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        final route = items[index].route;
        if (route != currentPath) {
          context.go(route);
        }
      },
      items: items
          .map((item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                activeIcon: Icon(item.activeIcon),
                label: item.label,
              ))
          .toList(),
    );
  }

  int _getActiveIndex(List<_NavItem> items, String currentPath) {
    for (var i = 0; i < items.length; i++) {
      if (currentPath == items[i].route) return i;
    }
    return 0;
  }

  static List<_NavItem> _getSupplierItems(AppLocalizations l10n) => [
    _NavItem(l10n.dashboard, Icons.home_outlined, Icons.home, '/supplier-dashboard'),
    _NavItem(l10n.myLoads, Icons.inventory_2_outlined, Icons.inventory_2, '/my-loads'),
    _NavItem(l10n.superDashboard, Icons.star_outline, Icons.star,
        '/supplier/super-dashboard'),
    _NavItem(l10n.messages, Icons.chat_bubble_outline, Icons.chat_bubble, '/messages'),
  ];

  static List<_NavItem> _getTruckerItems(AppLocalizations l10n) => [
    _NavItem(l10n.findLoads, Icons.home_outlined, Icons.home, '/find-loads'),
    _NavItem(l10n.myTrips, Icons.assignment_outlined, Icons.assignment, '/my-trips'),
    _NavItem(l10n.messages, Icons.chat_bubble_outline, Icons.chat_bubble, '/messages'),
    _NavItem(l10n.dashboard, Icons.bar_chart_outlined, Icons.bar_chart, '/trucker-dashboard'),
  ];
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _NavItem(this.label, this.icon, this.activeIcon, this.route);
}

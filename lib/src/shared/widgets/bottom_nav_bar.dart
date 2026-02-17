import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BottomNavBar extends StatelessWidget {
  final String currentRole;

  const BottomNavBar({super.key, required this.currentRole});

  @override
  Widget build(BuildContext context) {
    final items = currentRole == 'supplier' ? _supplierItems : _truckerItems;
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

  static const _supplierItems = [
    _NavItem('Home', Icons.home_outlined, Icons.home, '/supplier-dashboard'),
    _NavItem(
        'My Loads', Icons.inventory_2_outlined, Icons.inventory_2, '/my-loads'),
    _NavItem('Super', Icons.star_outline, Icons.star,
        '/supplier/super-dashboard'),
    _NavItem('Chat', Icons.chat_bubble_outline, Icons.chat_bubble, '/messages'),
  ];

  static const _truckerItems = [
    _NavItem('Home', Icons.search_outlined, Icons.search, '/find-loads'),
    _NavItem(
        'My Trips', Icons.assignment_outlined, Icons.assignment, '/my-trips'),
    _NavItem(
        'Fleet', Icons.local_shipping_outlined, Icons.local_shipping, '/my-fleet'),
    _NavItem('Chat', Icons.chat_bubble_outline, Icons.chat_bubble, '/messages'),
  ];
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _NavItem(this.label, this.icon, this.activeIcon, this.route);
}

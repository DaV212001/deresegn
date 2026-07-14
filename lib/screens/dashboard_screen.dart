import 'package:flutter/cupertino.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';

import 'invoice_generator_screen.dart';
import 'invoice_history_screen.dart';
import 'settings_screen.dart';
import 'supplies_screen.dart';

class DashboardScreen extends StatelessWidget {
  final PersistentTabController _controller = PersistentTabController(
    initialIndex: 0,
  );

  List<Widget> _buildScreens() {
    return [
      InvoiceGeneratorScreen(),
      InvoiceHistoryScreen(),
      const SuppliesScreen(),
      SettingsScreen(),
    ];
  }

  List<PersistentBottomNavBarItem> _navBarsItems() {
    return [
      PersistentBottomNavBarItem(
        icon: const Icon(CupertinoIcons.plus_square, size: 20),
        title: ("Register"),
        activeColorPrimary: const Color(0xFF00FFB3),
        inactiveColorPrimary: CupertinoColors.systemGrey,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(CupertinoIcons.square_list, size: 20),
        title: ("History"),
        activeColorPrimary: const Color(0xFF00FFB3),
        inactiveColorPrimary: CupertinoColors.systemGrey,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(CupertinoIcons.archivebox, size: 20),
        title: ("Products"),
        activeColorPrimary: const Color(0xFF00FFB3),
        inactiveColorPrimary: CupertinoColors.systemGrey,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(CupertinoIcons.settings),
        title: ("Settings"),
        activeColorPrimary: const Color(0xFF00FFB3),
        inactiveColorPrimary: CupertinoColors.systemGrey,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PersistentTabView(
      context,
      controller: _controller,
      screens: _buildScreens(),
      items: _navBarsItems(),
      backgroundColor: const Color(0xFF1F1F1F),
      handleAndroidBackButtonPress: true,
      resizeToAvoidBottomInset: true,
      stateManagement: true,
      navBarStyle: NavBarStyle.style6,
      navBarHeight: 70,
      padding: EdgeInsets.all(10),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

import '../l10n/app_localizations.dart';
import 'zoo_select_screen.dart';
import 'zoo_inventory_screen.dart' show ZooInventoryScreen, ZooInventoryArgs;
import 'species_detail_screen.dart' show SpeciesDetailScreen, SpeciesDetailArgs;
import 'zoodex_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _zooNavKey = GlobalKey<NavigatorState>();
  final _dexNavKey = GlobalKey<NavigatorState>();
  final _profileNavKey = GlobalKey<NavigatorState>();
  final _settingsNavKey = GlobalKey<NavigatorState>();

  GlobalKey<NavigatorState> get _activeKey {
    switch (_index) {
      case 0:
        return _zooNavKey;
      case 1:
        return _dexNavKey;
      case 2:
        return _profileNavKey;
      default:
        return _settingsNavKey;
    }
  }

  void _handlePop(bool didPop, Object? result) {
    if (didPop) return;
    final nav = _activeKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else {
      // At the root of this tab — exit the app (Android back behaviour).
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            Navigator(
              key: _zooNavKey,
              onGenerateRoute: (settings) {
                switch (settings.name) {
                  case '/inventory':
                    final args = settings.arguments as ZooInventoryArgs;
                    return MaterialPageRoute(
                      builder: (_) => ZooInventoryScreen(args: args),
                      settings: settings,
                    );
                  case '/detail':
                    final args = settings.arguments as SpeciesDetailArgs;
                    return MaterialPageRoute(
                      builder: (_) => SpeciesDetailScreen(args: args),
                      settings: settings,
                    );
                  default:
                    return MaterialPageRoute(
                      builder: (_) => const ZooSelectScreen(),
                      settings: settings,
                    );
                }
              },
            ),
            Navigator(
              key: _dexNavKey,
              onGenerateRoute: (settings) {
                switch (settings.name) {
                  case '/detail':
                    final args = settings.arguments as SpeciesDetailArgs;
                    return MaterialPageRoute(
                      builder: (_) => SpeciesDetailScreen(args: args),
                      settings: settings,
                    );
                  default:
                    return MaterialPageRoute(
                      builder: (_) => const ZooDexScreen(),
                      settings: settings,
                    );
                }
              },
            ),
            Navigator(
              key: _profileNavKey,
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                  settings: settings,
                );
              },
            ),
            Navigator(
              key: _settingsNavKey,
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                  settings: settings,
                );
              },
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _index,
          onTap: (i) {
            if (i == _index) {
              _activeKey.currentState?.popUntil((r) => r.isFirst);
            } else {
              setState(() => _index = i);
            }
          },
          items: [
            BottomNavigationBarItem(
                icon: const Icon(Icons.map),
                label: AppLocalizations.of(context).homeShellZoos),
            BottomNavigationBarItem(
              icon: const ImageIcon(AssetImage('assets/icons/species_icon.png')),
              label: AppLocalizations.of(context).homeShellSpecies,
            ),
            BottomNavigationBarItem(
                icon: const Icon(Icons.person),
                label: AppLocalizations.of(context).homeShellProfile),
            BottomNavigationBarItem(
                icon: const Icon(Icons.settings),
                label: AppLocalizations.of(context).commonSettings),
          ],
        ),
      ),
    );
  }
}

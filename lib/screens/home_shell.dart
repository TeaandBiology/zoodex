import 'package:flutter/material.dart';
import 'zoo_select_screen.dart';
import 'zoo_inventory_screen.dart' show ZooInventoryScreen, ZooInventoryArgs;
import 'species_detail_screen.dart' show SpeciesDetailScreen, SpeciesDetailArgs;
import 'zoodex_screen.dart';
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
  final _settingsNavKey = GlobalKey<NavigatorState>();

  Future<bool> _onWillPop() async {
    final currentKey = _index == 0 ? _zooNavKey : (_index == 1 ? _dexNavKey : _settingsNavKey);
    final nav = currentKey.currentState;
    if (nav == null) return true;

    if (nav.canPop()) {
      nav.pop();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            Navigator(
              key: _zooNavKey,
              onGenerateRoute: (settings) {
                switch (settings.name) {
                  case '/':
                    return MaterialPageRoute(
                      builder: (_) => const ZooSelectScreen(),
                      settings: settings,
                    );

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
                  case '/':
                    return MaterialPageRoute(
                      builder: (_) => const ZooDexScreen(),
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
                      builder: (_) => const ZooDexScreen(),
                      settings: settings,
                    );
                }
              },
            ),
            Navigator(
              key: _settingsNavKey,
              onGenerateRoute: (settings) {
                switch (settings.name) {
                  case '/':
                    return MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                      settings: settings,
                    );

                  default:
                    return MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                      settings: settings,
                    );
                }
              },
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) {
            if (i == _index) {
              final key = _index == 0 ? _zooNavKey : (_index == 1 ? _dexNavKey : _settingsNavKey);
              key.currentState?.popUntil((r) => r.isFirst);
            } else {
              setState(() => _index = i);
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Zoos'),
            BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Species'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

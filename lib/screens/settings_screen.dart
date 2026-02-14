import 'package:flutter/material.dart';
import '../data/settings_store.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: SettingsStore.nightMode,
            builder: (context, v, _) {
              return SwitchListTile(
                title: const Text('Night Mode'),
                value: v,
                onChanged: (nv) => SettingsStore.nightMode.value = nv,
              );
            },
          ),
          const ListTile(
            title: Text('More settings coming soon'),
          ),
        ],
      ),
    );
  }
}

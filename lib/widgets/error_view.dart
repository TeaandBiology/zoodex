import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// A simple centred error message, shown when something fails to load.
class ErrorView extends StatelessWidget {
  final Object? error;
  const ErrorView({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context).errorViewSomethingWentWrong,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? AppLocalizations.of(context).errorViewUnknownError,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

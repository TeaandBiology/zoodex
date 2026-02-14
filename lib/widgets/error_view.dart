import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  final Object? error;
  const ErrorView({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Failed to load.\n\n$error',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

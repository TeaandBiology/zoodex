import 'package:flutter/material.dart';

class ScientificName extends StatelessWidget {
  final String name;
  final String? suffix;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const ScientificName({
    super.key,
    required this.name,
    this.suffix,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final italic = baseStyle.copyWith(fontStyle: FontStyle.italic);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: name, style: italic),
          if (suffix != null) TextSpan(text: suffix, style: baseStyle),
        ],
      ),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.ellipsis,
    );
  }
}

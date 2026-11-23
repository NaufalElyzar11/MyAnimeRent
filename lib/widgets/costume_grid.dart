import 'package:flutter/material.dart';

/// Square cards retain their natural text height, including at large text sizes.
class CostumeGrid extends StatelessWidget {
  const CostumeGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
      final columns = largeText
          ? 1
          : (constraints.maxWidth / 160).floor().clamp(1, 4);
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

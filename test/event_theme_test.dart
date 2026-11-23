import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myanimerent/config/theme.dart';
import 'package:myanimerent/event/event_app.dart';

void main() {
  for (final brightness in Brightness.values) {
    test(
      'CTA ${brightness.name}: kontras teks normal >= 4.5 dan area sentuh >= 48',
      () {
        final theme = eventTheme(
          brightness == Brightness.light
              ? AppThemeData.lightTheme()
              : AppThemeData.darkTheme(),
        );
        final style = theme.filledButtonTheme.style!;
        final background = style.backgroundColor!.resolve({})!;
        final foreground = style.foregroundColor!.resolve({})!;
        final luminances = [
          background.computeLuminance(),
          foreground.computeLuminance(),
        ]..sort();
        final contrast = (luminances.last + 0.05) / (luminances.first + 0.05);
        expect(contrast, greaterThanOrEqualTo(4.5));
        final target = style.minimumSize!.resolve({})!;
        expect(target.width, greaterThanOrEqualTo(48));
        expect(target.height, greaterThanOrEqualTo(48));
      },
    );
  }
}

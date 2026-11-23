import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/event_safety.dart';
import 'event/event_app.dart';

/// Explicit offline build target. Does not import the legacy app or Firebase.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (appFlavor != 'event') {
    throw StateError(
      'Gunakan --flavor event -t lib/main_event.dart untuk APK uji yang terpisah.',
    );
  }
  EventSafety.disableCloud();
  runApp(const EventApp());
}

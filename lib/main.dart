import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'app.dart';
import 'config/event_safety.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (appFlavor == 'event') {
    throw StateError('Flavor event memerlukan lib/main_event.dart.');
  }
  EventSafety.requireCloudAccess();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyAnimeRentApp());
}

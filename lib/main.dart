import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/event_safety.dart';
import 'config/supabase_config.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (appFlavor == 'event') {
    throw StateError('Flavor event memerlukan lib/main_event.dart.');
  }
  EventSafety.requireCloudAccess();
  if (!SupabaseConfig.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }
  await initializeDateFormatting('id_ID');
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey);
  // Firebase hanya untuk push notification; app tetap berjalan bila tidak tersedia (mis. Windows/web).
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase (push) tidak aktif: $e');
  }
  runApp(const MyAnimeRentApp());
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Konfigurasi Supabase belum diisi.\n\n'
                'Jalankan dengan:\nflutter run --dart-define-from-file=env/local.json\n\n'
                'Contoh isi ada di env/local.example.json.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}

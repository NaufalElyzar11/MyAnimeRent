// Efek anime: muncul hanya saat diizinkan, lalu membersihkan dirinya sendiri.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myanimerent/widgets/sakuga.dart';

Finder _layer(String name) => find.byWidgetPredicate((w) => w.runtimeType.toString() == name);

Future<BuildContext> _host(WidgetTester tester, {bool reduceMotion = false}) async {
  late BuildContext ctx;
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: Center(
          child: Builder(builder: (c) {
            ctx = c;
            return const SizedBox(width: 80, height: 40);
          }),
        ),
      ),
    ),
  ));
  return ctx;
}

void main() {
  tearDown(() => Sakuga.enabled.value = true);

  testWidgets('ledakan muncul lalu hilang sendiri', (tester) async {
    final ctx = await _host(tester);
    Sakuga.burst(ctx, word: 'ドン!', haptic: false);
    await tester.pump();
    expect(_layer('_BurstLayer'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
    expect(_layer('_BurstLayer'), findsNothing);
  });

  testWidgets('efek mati di Pengaturan: tidak ada ledakan, toast jadi SnackBar biasa', (tester) async {
    Sakuga.enabled.value = false;
    final ctx = await _host(tester);
    Sakuga.burst(ctx, word: 'ドン!', haptic: false);
    Sakuga.toast(ctx, 'Tersimpan');
    await tester.pump();
    expect(_layer('_BurstLayer'), findsNothing);
    expect(_layer('_ToastLayer'), findsNothing);
    expect(find.text('Tersimpan'), findsOneWidget);
  });

  testWidgets('"kurangi animasi" di HP juga mematikan efek', (tester) async {
    final ctx = await _host(tester, reduceMotion: true);
    Sakuga.burst(ctx, haptic: false);
    await tester.pump();
    expect(_layer('_BurstLayer'), findsNothing);
  });

  testWidgets('toast meluncur masuk lalu hilang', (tester) async {
    final ctx = await _host(tester);
    Sakuga.toast(ctx, 'Permintaan terkirim');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Permintaan terkirim'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.text('Permintaan terkirim'), findsNothing);
  });

  testWidgets('tombol tetap bisa ditekan saat dibungkus efek memampat', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SakugaPressable(child: FilledButton(onPressed: () => taps++, child: const Text('Ajukan sewa'))),
        ),
      ),
    ));
    await tester.tap(find.text('Ajukan sewa'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}

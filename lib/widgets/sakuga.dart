import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';

/// Efek gerak bergaya anime ("sakuga") yang dipakai seperlunya:
/// tombol yang memampat saat ditekan, ledakan kecil + tulisan ドン! di momen penting,
/// kilau saat menyimpan favorit, toast yang meluncur, dan garis konsentrasi manga.
///
/// Semua efek mati bila pengguna mematikan "Efek anime" di Pengaturan atau
/// mengaktifkan "kurangi animasi" di HP; perubahan status tetap berjalan normal.
/// Diterapkan dengan CustomPaint (tanpa paket tambahan), terinspirasi gaya sakuga-vfx.
abstract final class Sakuga {
  /// Diatur oleh SettingsProvider (default menyala).
  static final ValueNotifier<bool> enabled = ValueNotifier(true);

  static bool isOn(BuildContext context) => enabled.value && !MediaQuery.disableAnimationsOf(context);

  /// Ledakan kecil di tengah widget [context] (atau [anchor]): garis kecepatan, cincin,
  /// pecahan kristal, dan [word] (mis. 'ドン!'). [scale] 1 = momen besar, 0,5 = kilau kecil.
  static void burst(
    BuildContext context, {
    GlobalKey? anchor,
    String? word,
    double scale = 1,
    bool haptic = true,
  }) {
    if (!isOn(context)) return;
    final target = anchor?.currentContext ?? context;
    final box = target.findRenderObject();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (box is! RenderBox || !box.hasSize || overlay == null) return;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    if (haptic) HapticFeedback.lightImpact();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _BurstLayer(
        center: center,
        word: word,
        scale: scale,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  /// Pesan sukses yang meluncur masuk (smear), mendarat dengan debu, lalu mengecil keluar.
  /// Bila efek mati, memakai SnackBar biasa.
  static void toast(BuildContext context, String message, {IconData icon = Icons.check_rounded}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (!isOn(context) || overlay == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastLayer(message: message, icon: icon, onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  }
}

// ─── Tombol memampat (squash & stretch) ───────────────────────────────────

/// Membungkus tombol: memampat saat ditekan, lalu memantul memanjang saat dilepas.
class SakugaPressable extends StatefulWidget {
  const SakugaPressable({super.key, required this.child});
  final Widget child;

  @override
  State<SakugaPressable> createState() => _SakugaPressableState();
}

class _SakugaPressableState extends State<SakugaPressable> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, lowerBound: -1, upperBound: 1, value: 0);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent _) {
    if (!Sakuga.isOn(context)) return;
    _c.animateTo(1, duration: const Duration(milliseconds: 90), curve: Curves.easeOut);
  }

  void _up(PointerEvent _) {
    if (!Sakuga.isOn(context)) return;
    _c.animateTo(0, duration: const Duration(milliseconds: 420), curve: Curves.elasticOut);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final v = _c.value; // >0 memampat, <0 (pantulan elastis) memanjang
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(1 + 0.05 * v, 1 - 0.10 * v, 1),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Ikon yang "meloncat" saat muncul (ikon tab terpilih, hati favorit).
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.from = 0.5});
  final Widget child;
  final double from;

  @override
  Widget build(BuildContext context) {
    if (!Sakuga.isOn(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: from, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
      builder: (_, s, c) => Transform.scale(scale: s, child: c),
      child: child,
    );
  }
}

// ─── Garis konsentrasi manga (集中線) ───────────────────────────────────────

/// Garis-garis tipis yang memusat ke tengah, seperti panel manga. Dipakai samar di
/// belakang ilustrasi kosong/berhasil. Bergetar pelan bila efek menyala.
class SpeedLines extends StatefulWidget {
  const SpeedLines({super.key, required this.size, this.child, this.color, this.opacity = 0.10});
  final double size;
  final Widget? child;
  final Color? color;
  final double opacity;

  @override
  State<SpeedLines> createState() => _SpeedLinesState();
}

class _SpeedLinesState extends State<SpeedLines> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..addStatusListener(_onStatus);
  int _loops = 0;
  bool _started = false;

  // Bergetar sebentar saat muncul (±5 detik), lalu diam agar tidak mengganggu.
  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && ++_loops < 3 && mounted) _c.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && Sakuga.isOn(context)) {
      _started = true;
      _c.forward(from: 0);
    } else if (!Sakuga.isOn(context)) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = (widget.color ?? Theme.of(context).colorScheme.onSurface).withValues(alpha: widget.opacity);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) => CustomPaint(
                  // Berganti pola 4 kali per putaran: kesan "bergetar" khas manga, bukan berputar.
                  painter: _SpeedLinesPainter(color: color, seed: (_c.value * 4).floor()),
                ),
              ),
            ),
          ),
          ?widget.child,
        ],
      ),
    );
  }
}

class _SpeedLinesPainter extends CustomPainter {
  _SpeedLinesPainter({required this.color, required this.seed});
  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final rnd = math.Random(seed + 7);
    final paint = Paint()..color = color;
    const lines = 44;
    for (var i = 0; i < lines; i++) {
      final a = (i / lines) * math.pi * 2 + rnd.nextDouble() * 0.08;
      final inner = outer * (0.52 + rnd.nextDouble() * 0.22);
      final w = 0.010 + rnd.nextDouble() * 0.018; // lebar sudut di ujung luar
      final path = Path()
        ..moveTo(c.dx + math.cos(a) * inner, c.dy + math.sin(a) * inner)
        ..lineTo(c.dx + math.cos(a - w) * outer, c.dy + math.sin(a - w) * outer)
        ..lineTo(c.dx + math.cos(a + w) * outer, c.dy + math.sin(a + w) * outer)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SpeedLinesPainter old) => old.seed != seed || old.color != color;
}

// ─── Ledakan (burst) ───────────────────────────────────────────────────────

class _BurstLayer extends StatefulWidget {
  const _BurstLayer({required this.center, required this.word, required this.scale, required this.onDone});
  final Offset center;
  final String? word;
  final double scale;
  final VoidCallback onDone;

  @override
  State<_BurstLayer> createState() => _BurstLayerState();
}

class _BurstLayerState extends State<_BurstLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.word == null ? 560 : 900),
  )..forward().whenComplete(widget.onDone);
  late final int _seed = math.Random().nextInt(1 << 20);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(
            size: Size.infinite,
            painter: _BurstPainter(
              t: _c.value,
              center: widget.center,
              word: widget.word,
              scale: widget.scale,
              seed: _seed,
              dark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.t,
    required this.center,
    required this.word,
    required this.scale,
    required this.seed,
    required this.dark,
  });

  final double t;
  final Offset center;
  final String? word;
  final double scale;
  final int seed;
  final bool dark;

  static const _palette = [AppColors.pink, AppColors.purple, AppColors.yellow];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final s = scale;
    final out = Curves.easeOutCubic.transform(t.clamp(0.0, 0.6) / 0.6);
    final fade = (1 - t).clamp(0.0, 1.0);

    // 1. Kilatan + cincin kejut.
    if (t < 0.18) {
      canvas.drawCircle(center, 22 * s * (1 + t * 4),
          Paint()..color = Colors.white.withValues(alpha: dark ? 0.25 : 0.7 * (1 - t / 0.18)));
    }
    canvas.drawCircle(
      center,
      (16 + 84 * out) * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (5 * (1 - out) + 0.5) * s
        ..color = AppColors.pink.withValues(alpha: 0.85 * fade),
    );

    // 2. Baji kecepatan memancar (impact wedges).
    final wedges = (14 * s).round().clamp(6, 16);
    for (var i = 0; i < wedges; i++) {
      final a = (i / wedges) * math.pi * 2 + rnd.nextDouble() * 0.3;
      final start = (20 + 50 * out) * s;
      final len = (26 + rnd.nextDouble() * 24) * s * (1 - out * 0.85);
      final w = 0.07 + rnd.nextDouble() * 0.05;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * start;
      final p2 = center + Offset(math.cos(a - w), math.sin(a - w)) * (start + len);
      final p3 = center + Offset(math.cos(a + w), math.sin(a + w)) * (start + len);
      canvas.drawPath(
        Path()
          ..moveTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close(),
        Paint()..color = _palette[i % _palette.length].withValues(alpha: fade),
      );
    }

    // 3. Pecahan kristal berputar, sedikit jatuh.
    final shards = (10 * s).round().clamp(5, 12);
    for (var i = 0; i < shards; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final dist = (30 + rnd.nextDouble() * 70) * s * Curves.easeOut.transform(t);
      final drop = 30 * s * t * t;
      final p = center + Offset(math.cos(a) * dist, math.sin(a) * dist + drop);
      final r = (3 + rnd.nextDouble() * 4) * s * (1 - t * 0.6);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a + t * 6);
      canvas.drawPath(
        Path()
          ..moveTo(0, -r * 1.6)
          ..lineTo(r * 0.7, 0)
          ..lineTo(0, r * 1.6)
          ..lineTo(-r * 0.7, 0)
          ..close(),
        Paint()..color = _palette[(i + 1) % _palette.length].withValues(alpha: fade),
      );
      canvas.restore();
    }

    // 4. Kepulan asap kecil di sudut.
    if (s >= 0.8) {
      for (var i = 0; i < 3; i++) {
        final a = math.pi * (0.8 + i * 0.55) + rnd.nextDouble() * 0.4;
        final p = center + Offset(math.cos(a), math.sin(a)) * (44 + 36 * out) * s;
        canvas.drawCircle(
          p,
          (8 + 10 * out) * s,
          Paint()..color = (dark ? Colors.white : AppColors.purple).withValues(alpha: 0.16 * fade),
        );
      }
    }

    // 5. Tulisan efek suara (onomatope) dengan garis tepi tebal.
    final w = word;
    if (w != null) {
      final pop = t < 0.22 ? Curves.easeOutBack.transform(t / 0.22) * 1.18 : (t < 0.32 ? 1.18 - (t - 0.22) / 0.10 * 0.18 : 1.0);
      final wordFade = t > 0.75 ? (1 - (t - 0.75) / 0.25) : 1.0;
      final style = TextStyle(
        fontSize: 40 * s,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: -1,
        height: 1,
      );
      final stroke = TextPainter(
        text: TextSpan(
          text: w,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 7 * s
              ..strokeJoin = StrokeJoin.round
              ..color = AppColors.darkGrey.withValues(alpha: wordFade),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final fill = TextPainter(
        text: TextSpan(text: w, style: style.copyWith(color: AppColors.yellow.withValues(alpha: wordFade))),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(center.dx + 18 * s, center.dy - 58 * s - 10 * t * s);
      canvas.rotate(-0.16);
      canvas.scale(pop.clamp(0.0, 1.3));
      final o = Offset(-fill.width / 2, -fill.height / 2);
      stroke.paint(canvas, o);
      fill.paint(canvas, o);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

// ─── Toast meluncur ────────────────────────────────────────────────────────

class _ToastLayer extends StatefulWidget {
  const _ToastLayer({required this.message, required this.icon, required this.onDone});
  final String message;
  final IconData icon;
  final VoidCallback onDone;

  @override
  State<_ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends State<_ToastLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 96;
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = _c.value;
            // 0–0,1: meluncur dari kanan dengan miring (smear); 0,1–0,16: mendarat; 0,9–1: mengecil keluar.
            final enter = Curves.easeOutCubic.transform((t / 0.1).clamp(0.0, 1.0));
            final exit = t > 0.9 ? Curves.easeIn.transform((t - 0.9) / 0.1) : 0.0;
            final dx = (1 - enter) * MediaQuery.sizeOf(context).width;
            final skew = (1 - enter) * -0.45;
            final scale = 1 - exit * 0.4;
            return Opacity(
              opacity: (1 - exit).clamp(0.0, 1.0),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.translationValues(dx, 0, 0)
                  ..multiply(Matrix4.skewX(skew))
                  ..multiply(Matrix4.diagonal3Values(scale, scale, 1)),
                child: CustomPaint(
                  painter: _DustPainter(t: t),
                  foregroundPainter: _SmearPainter(progress: enter),
                  child: child,
                ),
              ),
            );
          },
          child: Material(
            color: AppColors.darkGrey,
            elevation: 6,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.pink,
                    child: Icon(widget.icon, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Garis-garis gerak di belakang toast saat meluncur.
class _SmearPainter extends CustomPainter {
  _SmearPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1) return;
    final paint = Paint()
      ..color = AppColors.pink.withValues(alpha: 0.6 * (1 - progress))
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.2 + i * 0.2);
      final len = size.width * (0.35 + 0.1 * (i % 2)) * (1 - progress);
      canvas.drawLine(Offset(size.width + 8, y), Offset(size.width + 8 + len, y), paint);
    }
  }

  @override
  bool shouldRepaint(_SmearPainter old) => old.progress != progress;
}

/// Debu kecil di kedua ujung bawah saat toast "mendarat".
class _DustPainter extends CustomPainter {
  _DustPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t < 0.09 || t > 0.22) return;
    final k = (t - 0.09) / 0.13;
    final paint = Paint()..color = AppColors.purple.withValues(alpha: 0.22 * (1 - k));
    for (final side in [-1.0, 1.0]) {
      final base = Offset(side < 0 ? 0 : size.width, size.height);
      for (var i = 0; i < 3; i++) {
        final p = base + Offset(side * (6 + i * 10 + k * 14), -4 - i * 3 - k * 6);
        canvas.drawCircle(p, 4 + i * 2 + k * 5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) => old.t != t;
}

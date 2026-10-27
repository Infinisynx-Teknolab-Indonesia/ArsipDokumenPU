import 'package:flutter/material.dart';
import '../theme/ym_theme.dart';

/// Latar layar login: "gambar kerja" jembatan gantung di atas grid cetak biru,
/// garis putih tipis + marka jalan kuning. Gambar tergambar sendiri satu kali
/// saat dibuka (animasi ±2 detik), lalu diam. Animasi dilewati bila pengguna
/// mematikan animasi di sistem operasi.
class LoginHeroBackground extends StatefulWidget {
  const LoginHeroBackground({super.key});

  @override
  State<LoginHeroBackground> createState() => _LoginHeroBackgroundState();
}

class _LoginHeroBackgroundState extends State<LoginHeroBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status == AnimationStatus.dismissed) {
      if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: YmColors.ink,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _BlueprintPainter(Curves.easeInOutCubic.transform(_c.value)),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BlueprintPainter extends CustomPainter {
  final double t; // 0..1 kemajuan gambar
  _BlueprintPainter(this.t);

  /// Gambar sebagian path sesuai kemajuan [p] (0..1).
  void _drawPartial(Canvas canvas, Path path, Paint paint, double p) {
    if (p <= 0) return;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * p.clamp(0.0, 1.0).toDouble()), paint);
    }
  }

  /// Kemajuan bagian tertentu dari keseluruhan animasi.
  double _seg(double start, double end) => ((t - start) / (end - start)).clamp(0.0, 1.0).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // ---- grid cetak biru (halus) — langsung tampil, memudar masuk
    final fine = Paint()
      ..color = Colors.white.withOpacity(0.035 * _seg(0, 0.25))
      ..strokeWidth = 1;
    final major = Paint()
      ..color = Colors.white.withOpacity(0.06 * _seg(0, 0.25))
      ..strokeWidth = 1;
    const step = 24.0;
    var i = 0;
    for (double x = 0; x <= w; x += step, i++) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), i % 5 == 0 ? major : fine);
    }
    i = 0;
    for (double y = 0; y <= h; y += step, i++) {
      canvas.drawLine(Offset(0, y), Offset(w, y), i % 5 == 0 ? major : fine);
    }

    // ---- jembatan gantung (tampak samping)
    final deckY = h * 0.66;
    final pylonTop = h * 0.30;
    final p1 = w * 0.22, p2 = w * 0.70;
    final line = Paint()
      ..color = Colors.white.withOpacity(0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final thin = Paint()
      ..color = Colors.white.withOpacity(0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // lantai jembatan (dua garis)
    final deck = Path()
      ..moveTo(-10, deckY)
      ..lineTo(w + 10, deckY)
      ..moveTo(-10, deckY + 10)
      ..lineTo(w + 10, deckY + 10);
    _drawPartial(canvas, deck, line, _seg(0.05, 0.40));

    // pilon (menara) — bentuk huruf A ramping
    Path pylon(double x) => Path()
      ..moveTo(x - 10, deckY + 70)
      ..lineTo(x - 4, pylonTop)
      ..lineTo(x + 4, pylonTop)
      ..lineTo(x + 10, deckY + 70)
      ..moveTo(x - 7, pylonTop + (deckY - pylonTop) * 0.35)
      ..lineTo(x + 7, pylonTop + (deckY - pylonTop) * 0.35);
    _drawPartial(canvas, pylon(p1), line, _seg(0.20, 0.50));
    _drawPartial(canvas, pylon(p2), line, _seg(0.25, 0.55));

    // kabel utama (parabola) antar pilon dan ke tepi
    final main = Path()
      ..moveTo(-10, deckY - 20)
      ..quadraticBezierTo(p1 * 0.6, deckY - 30, p1, pylonTop)
      ..quadraticBezierTo((p1 + p2) / 2, deckY + (deckY - pylonTop) * 0.55, p2, pylonTop)
      ..quadraticBezierTo(p2 + (w - p2) * 0.4, deckY - 30, w + 10, deckY - 20);
    _drawPartial(canvas, main, line, _seg(0.40, 0.75));

    // kabel penggantung vertikal
    final hp = _seg(0.60, 0.90);
    if (hp > 0) {
      final metric = main.computeMetrics().first;
      const n = 46;
      for (var k = 1; k < n; k++) {
        if (k / n > hp) break;
        final pos = metric.getTangentForOffset(metric.length * k / n)?.position;
        if (pos == null || pos.dy >= deckY - 4) continue;
        canvas.drawLine(pos, Offset(pos.dx, deckY), thin);
      }
    }

    // ---- garis ukur (dimensi) antar pilon, gaya gambar teknik
    final dp = _seg(0.75, 1.0);
    if (dp > 0) {
      final dim = Paint()
        ..color = Colors.white.withOpacity(0.35 * dp)
        ..strokeWidth = 1;
      final dy = deckY + 110;
      canvas.drawLine(Offset(p1, dy), Offset(p1 + (p2 - p1) * dp, dy), dim);
      canvas.drawLine(Offset(p1, deckY + 74), Offset(p1, dy + 8), dim);
      if (dp >= 1) canvas.drawLine(Offset(p2, deckY + 74), Offset(p2, dy + 8), dim);
      for (final x in [p1, p2]) {
        canvas.drawLine(Offset(x - 5, dy + 5), Offset(x + 5, dy - 5), dim..strokeWidth = 1.4);
      }
      final tp = TextPainter(
        text: TextSpan(
          text: 'Bentang utama',
          style: TextStyle(fontFamily: kFont, color: Colors.white.withOpacity(0.35 * dp), fontSize: 11, letterSpacing: 0.6),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((p1 + p2) / 2 - tp.width / 2, dy - 18));
    }

    // ---- jalan + marka kuning putus-putus di bawah
    final roadY = h * 0.93;
    final mp = _seg(0.10, 0.60);
    if (mp > 0) {
      final edge = Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(0, roadY - 22), Offset(w * mp, roadY - 22), edge);
      canvas.drawLine(Offset(0, roadY + 22), Offset(w * mp, roadY + 22), edge);
      final marka = Paint()
        ..color = YmColors.marka.withOpacity(0.9)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      for (double x = 20; x < w * mp; x += 64) {
        canvas.drawLine(Offset(x, roadY), Offset(x + 30, roadY), marka);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BlueprintPainter old) => old.t != t;
}

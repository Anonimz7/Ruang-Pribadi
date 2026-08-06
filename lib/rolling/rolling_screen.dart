import 'dart:math';
import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════
/// ROLLING — Undi Yes / No (Meja Rollet)
/// ═══════════════════════════════════════════════════════
/// 10 grid: YES, NO, YES, NO ... (5 yes, 5 no).
/// Random murni berbasis timestamp. Putaran 10–30 detik,
/// kecepatan awal acak 95–100 (max=100), melambat hingga berhenti.
/// ═══════════════════════════════════════════════════════

enum YesNo { yes, no }

extension YesNoX on YesNo {
  String get label => this == YesNo.yes ? 'YES' : 'NO';
  Color get color =>
      this == YesNo.yes ? const Color(0xFF00C87A) : const Color(0xFFE74C3C);
  IconData get icon => this == YesNo.yes ? Icons.check_circle : Icons.cancel;
}

class RollingScreen extends StatefulWidget {
  const RollingScreen({super.key});

  @override
  State<RollingScreen> createState() => _RollingScreenState();
}

class _RollingScreenState extends State<RollingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _rng = Random();

  YesNo? _result;
  bool _spinning = false;

  double _baseRotation = 0;
  double _spinAngle = 0;
  YesNo _target = YesNo.yes;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _spinning = false;
            _result = _target;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Random murni berbasis timestamp
  YesNo _roll() {
    final rng = Random(DateTime.now().microsecondsSinceEpoch);
    return rng.nextBool() ? YesNo.yes : YesNo.no;
  }

  void _spin() {
    if (_spinning) return;
    final target = _roll();

    // 10 sektor selang-seling: index genap = YES, ganjil = NO
    const n = 10;
    final sectorAngle = 360 / n;
    final index = target == YesNo.yes ? 0 : 1;
    final tierCenter = sectorAngle * index + sectorAngle / 2;
    final jitter = _rng.nextDouble() * sectorAngle * 0.6 - sectorAngle * 0.3;

    // Sektor target berhenti di bawah jarum statis (posisi jam 12 = 270°)
    // Kurangi _baseRotation agar benar untuk putaran ke-2 dst.
    var targetAngle = 270 - tierCenter - _baseRotation + jitter;
    targetAngle = ((targetAngle % 360) + 360) % 360;

    // Durasi acak 10–30 detik
    final T = 10 + _rng.nextDouble() * 20;

    // Kecepatan awal acak 95–100 (max = 100) → ×8 = 760–800 °/s
    const maxSpeed = 100;
    const speedScale = 8;
    final v0 = maxSpeed * (0.95 + _rng.nextDouble() * 0.05) * speedScale;

    // Total sudut = N putaran penuh + offset target, konsisten dgn v0·T/2
    final rotations = ((v0 * T / 2) / 360).floor();
    final totalAngle = rotations * 360 + targetAngle;
    final v0Final = 2 * totalAngle / T;

    setState(() {
      _spinning = true;
      _result = null;
      _baseRotation = _baseRotation + _spinAngle;
      _spinAngle = totalAngle;
      _target = target;
    });

    _controller.value = 0;
    _controller.duration = Duration(milliseconds: (T * 1000).round());
    _controller.animateWith(
        _DecelerationSimulation(v0: v0Final, totalAngle: totalAngle, T: T));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Putar roda untuk mengundi YES atau NO!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // ─── Meja Rollet ─────────────────────
              SizedBox(
                width: 300,
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Roda berputar
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: (_baseRotation +
                                  _controller.value * _spinAngle) *
                              pi / 180,
                          child: child,
                        );
                      },
                      child: const CustomPaint(
                        size: Size(280, 280),
                        painter: _YesNoPainter(),
                      ),
                    ),
                    // Jarum statis di atas roda
                    Positioned(
                      top: 2,
                      child: IgnorePointer(
                        child: CustomPaint(
                          size: const Size(26, 56),
                          painter: _NeedlePainter(
                              color: _result?.color ?? Colors.red),
                        ),
                      ),
                    ),
                    // Tombol tengah
                    GestureDetector(
                      onTap: _spin,
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00C87A), Color(0xFF00995E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.casino,
                                color: Colors.white, size: 22),
                            SizedBox(height: 2),
                            Text('GO!',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Hasil ───────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _result == null
                    ? const SizedBox(
                        height: 100,
                        child: Center(
                            child: Text('Tekan GO untuk mengundi',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13))),
                      )
                    : _ResultCard(
                        key: ValueKey(_result),
                        result: _result!,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final YesNo result;
  const _ResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: result.color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: result.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(result.icon, size: 40, color: result.color),
          const SizedBox(height: 6),
          Text(result.label,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: result.color)),
        ],
      ),
    );
  }
}

/// Painter roda — 10 sektor selang-seling YES/NO
class _YesNoPainter extends CustomPainter {
  const _YesNoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const n = 10;
    final sweep = 360 / n;

    canvas.drawCircle(center, radius, Paint()..color = Colors.black26);

    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < n; i++) {
      paint.color = i.isEven ? const Color(0xFF00C87A) : const Color(0xFFE74C3C);
      canvas.drawArc(rect, i * sweep * pi / 180, sweep * pi / 180, true, paint);
    }

    // Label YES/NO di tiap sektor
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    for (var i = 0; i < n; i++) {
      final mid = (i * sweep + sweep / 2) * pi / 180;
      final label = i.isEven ? 'YES' : 'NO';
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      final pos = center +
          Offset(cos(mid), sin(mid)) * (radius * 0.72) -
          Offset(textPainter.width / 2, textPainter.height / 2);
      textPainter.paint(canvas, pos);
    }

    // Garis antar sektor
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    for (var i = 0; i < n; i++) {
      final angle = i * sweep * pi / 180;
      canvas.drawLine(
          center, center + Offset(cos(angle), sin(angle)) * radius, line);
    }

    // Bingkai luar
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _YesNoPainter old) => false;
}

/// Jarum penunjuk statis — segitiga runcing ke bawah + pivot
class _NeedlePainter extends CustomPainter {
  final Color color;
  const _NeedlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final body = Path()
      ..moveTo(w * 0.5, h)
      ..lineTo(w * 0.06, 0)
      ..lineTo(w * 0.94, 0)
      ..close();
    canvas.drawPath(
      body.shift(const Offset(1.5, 2)),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.drawPath(body, Paint()..color = color);

    canvas.drawCircle(
        Offset(w / 2, 0), w * 0.16, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w / 2, 0), w * 0.10, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter old) => old.color != color;
}

/// Simulasi fisika putaran: v(t) = v0·(1 - t/T), θ(t) = v0·t·(1 - t/2T).
/// Mengembalikan nilai ternormalisasi 0..1 (AnimationController clamp [0,1]).
class _DecelerationSimulation extends Simulation {
  final double v0;
  final double totalAngle;
  final double T;

  _DecelerationSimulation(
      {required this.v0, required this.totalAngle, required this.T});

  @override
  double x(double timeInSeconds) =>
      v0 * timeInSeconds * (1 - timeInSeconds / (2 * T)) / totalAngle;

  @override
  double dx(double timeInSeconds) =>
      v0 * (1 - timeInSeconds / T) / totalAngle;

  @override
  bool isDone(double timeInSeconds) => timeInSeconds >= T;
}
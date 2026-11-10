import 'package:flutter/material.dart';
import '../core/theme.dart';

class RuchaLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool showFlag;

  const RuchaLogo({
    super.key,
    this.size = 48.0,
    this.showText = true,
    this.showFlag = true,
  });

  @override
  Widget build(BuildContext context) {
    final logoWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF121A18),
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset(
          'assets/rucha_logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => CustomPaint(
            size: Size(size, size),
            painter: _RuchaLogoPainter(),
          ),
        ),
      ),
    );

    if (!showText) return logoWidget;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logoWidget,
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'RUCHA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: RuchaTheme.accentGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: RuchaTheme.accentGold.withOpacity(0.4)),
              ),
              child: const Text(
                'ETHIOPIA',
                style: TextStyle(
                  color: RuchaTheme.accentGold,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        if (showFlag) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 14, height: 2.5, color: const Color(0xFF009B48)),
              Container(width: 14, height: 2.5, color: const Color(0xFFFED100)),
              Container(width: 14, height: 2.5, color: const Color(0xFFEF3340)),
            ],
          ),
        ],
      ],
    );
  }
}

class _RuchaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.42;

    // Ring
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, r, ringPaint);

    // Track path (8,27 -> 15,17 -> 20,22 -> 27,10 -> 33,20)
    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.675);
    path.lineTo(size.width * 0.375, size.height * 0.425);
    path.lineTo(size.width * 0.5, size.height * 0.55);
    path.lineTo(size.width * 0.675, size.height * 0.25);
    path.lineTo(size.width * 0.825, size.height * 0.5);

    final trackPaint = Paint()
      ..color = const Color(0xFFFF6B35)
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, trackPaint);

    // Green start
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.675), size.width * 0.065, Paint()..color = const Color(0xFF12A88A));
    // Gold summit
    canvas.drawCircle(Offset(size.width * 0.675, size.height * 0.25), size.width * 0.085, Paint()..color = const Color(0xFFF2B705));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

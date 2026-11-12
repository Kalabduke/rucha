import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Ember Fitness-inspired stat card.
///
/// [accent] — if provided, renders as a vivid coloured "hero" card
/// (like the orange Duration card in the reference image).
/// Without [accent] it uses the neutral dark surface.
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color? iconColor;
  final Color? accent; // set for hero/filled variant

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.iconColor,
    this.accent,
  });

  bool get _isHero => accent != null;

  @override
  Widget build(BuildContext context) {
    final bg = _isHero ? accent! : RuchaTheme.surface2;
    final textColor = Colors.white;
    final subColor =
        _isHero ? Colors.white.withOpacity(0.65) : RuchaTheme.textSecondary;
    final ic = _isHero ? Colors.white : (iconColor ?? RuchaTheme.accentGreen);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        gradient: _isHero
            ? LinearGradient(
                colors: [accent!, Color.lerp(accent!, Colors.black, 0.22)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        boxShadow: _isHero
            ? RuchaTheme.cardShadow(color: accent, opacity: 0.30)
            : RuchaTheme.cardShadow(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: subColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        height: 1.0,
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        unit,
                        style: TextStyle(
                          color: subColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Icon badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _isHero
                  ? Colors.white.withOpacity(0.18)
                  : (iconColor ?? RuchaTheme.accentGreen).withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: ic),
          ),
        ],
      ),
    );
  }
}

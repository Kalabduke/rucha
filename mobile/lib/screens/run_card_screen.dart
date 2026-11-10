import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../models/legend_ghost.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../widgets/route_painter.dart';

enum CardThemeStyle { sunset, midnight, ember }

class RunCardScreen extends StatefulWidget {
  final Activity activity;
  final LegendGhost? ghostLegend;

  const RunCardScreen({super.key, required this.activity, this.ghostLegend});

  @override
  State<RunCardScreen> createState() => _RunCardScreenState();
}

class _RunCardScreenState extends State<RunCardScreen> {
  CardThemeStyle _currentStyle = CardThemeStyle.sunset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Run Card Studio'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Card ready to share on Instagram & Telegram!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Style Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _styleChip('Sunset', CardThemeStyle.sunset, const Color(0xFFFF7A42)),
                  const SizedBox(width: 8),
                  _styleChip('Midnight', CardThemeStyle.midnight, const Color(0xFF5FD6A8)),
                  const SizedBox(width: 8),
                  _styleChip('Ember', CardThemeStyle.ember, const Color(0xFFF2B705)),
                ],
              ),
              const SizedBox(height: 18),

              // The Artistic Run Card (Aspect ratio 4:5 for Instagram / Stories)
              AspectRatio(
                aspectRatio: 0.8,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: _getGradient(),
                    boxShadow: [
                      BoxShadow(
                        color: _getAccentColor().withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // Map Route in Background
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(36.0),
                            child: CustomPaint(
                              painter: RoutePainter(
                                points: widget.activity.track,
                                routeColor: _getAccentColor(),
                                showPoints: true,
                              ),
                            ),
                          ),
                        ),

                        // Card Overlay Content
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Top Bar
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                                        ),
                                        child: Text(
                                          RuchaConstants.appName,
                                          style: TextStyle(
                                            color: _getAccentColor(),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                            letterSpacing: 2.0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    RuchaConstants.cities[widget.activity.city]?.name ?? 'Ethiopia',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),

                              // Bottom Stats
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.ghostLegend != null) ...[
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.45),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: widget.ghostLegend!.accentColor.withOpacity(0.6)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(widget.ghostLegend!.icon, style: const TextStyle(fontSize: 14)),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Paced vs ${widget.ghostLegend!.name} (${widget.ghostLegend!.targetPaceFormatted})',
                                            style: TextStyle(
                                              color: widget.ghostLegend!.accentColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  Text(
                                    widget.activity.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _cardStat(
                                        'DISTANCE',
                                        '${widget.activity.distance.toStringAsFixed(2)} km',
                                      ),
                                      _cardStat(
                                        'TIME',
                                        RuchaConstants.formatDuration(widget.activity.duration),
                                      ),
                                      _cardStat(
                                        'PACE',
                                        '${RuchaConstants.formatPace(widget.activity.pace)} /km',
                                      ),
                                      _cardStat(
                                        'ELEVATION',
                                        '+${widget.activity.elevation.round()} m',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Card saved to gallery!')),
                  );
                },
                icon: const Icon(CupertinoIcons.arrow_down_doc),
                label: const Text('Export High-Res Card'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _styleChip(String label, CardThemeStyle style, Color color) {
    final active = _currentStyle == style;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: color.withOpacity(0.2),
      labelStyle: TextStyle(
        color: active ? color : RuchaTheme.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _currentStyle = style),
    );
  }

  LinearGradient _getGradient() {
    switch (_currentStyle) {
      case CardThemeStyle.sunset:
        return const LinearGradient(
          colors: [Color(0xFF2B1006), Color(0xFF130602), Color(0xFF090302)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardThemeStyle.midnight:
        return const LinearGradient(
          colors: [Color(0xFF091F18), Color(0xFF040F0C), Color(0xFF020706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardThemeStyle.ember:
        return const LinearGradient(
          colors: [Color(0xFF2E1A04), Color(0xFF140B01), Color(0xFF070400)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Color _getAccentColor() {
    switch (_currentStyle) {
      case CardThemeStyle.sunset:
        return const Color(0xFFFF7A42);
      case CardThemeStyle.midnight:
        return const Color(0xFF5FD6A8);
      case CardThemeStyle.ember:
        return const Color(0xFFF2B705);
    }
  }

  Widget _cardStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

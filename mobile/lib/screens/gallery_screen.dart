import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../models/legend_ghost.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import 'run_card_screen.dart';

class GalleryCardItem {
  final String id;
  final String title;
  final String city;
  final double distance;
  final int duration;
  final double pace;
  final double elevation;
  final String theme; // 'sunset', 'midnight', 'ember'
  final LegendGhost? ghostLegend;
  final DateTime createdAt;

  GalleryCardItem({
    required this.id,
    required this.title,
    required this.city,
    required this.distance,
    required this.duration,
    required this.pace,
    required this.elevation,
    this.theme = 'sunset',
    this.ghostLegend,
    required this.createdAt,
  });
}

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final List<GalleryCardItem> _cards = [
    GalleryCardItem(
      id: 'g1',
      title: 'Entoto Eucalyptus Forest Loop',
      city: 'Addis Ababa',
      distance: 10.25,
      duration: 3120,
      pace: 304.0,
      elevation: 410.0,
      theme: 'sunset',
      ghostLegend: LegendGhost.all[0], // Abebe Bikila
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    GalleryCardItem(
      id: 'g2',
      title: 'Meskel Square Evening Tempo',
      city: 'Addis Ababa',
      distance: 6.50,
      duration: 1680,
      pace: 258.0,
      elevation: 60.0,
      theme: 'midnight',
      ghostLegend: LegendGhost.all[1], // Haile G
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    GalleryCardItem(
      id: 'g3',
      title: 'Bishoftu Lake View Cruise',
      city: 'Bishoftu',
      distance: 14.80,
      duration: 4440,
      pace: 300.0,
      elevation: 120.0,
      theme: 'ember',
      ghostLegend: LegendGhost.all[3], // Derartu Tulu
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Container(height: 2.5, color: RuchaTheme.accentGreen)),
                Expanded(child: Container(height: 2.5, color: RuchaTheme.accentGold)),
                Expanded(child: Container(height: 2.5, color: RuchaTheme.accentRed)),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                Text('Run Card Gallery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(width: 8),
                Text('ጋለሪ ስቱዲዮ', style: TextStyle(fontSize: 12, color: RuchaTheme.accentGold, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.camera_fill, color: RuchaTheme.accentGreen),
            tooltip: 'Create Card',
            onPressed: () => _openCardCreator(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _cards.isEmpty
          ? _buildEmptyState(context)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: RuchaTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: RuchaTheme.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.sparkles, color: RuchaTheme.accentGold, size: 22),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Artistic 4:5 Run Cards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              SizedBox(height: 2),
                              Text('Formatted for Instagram Stories & Telegram channels.', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: _cards.length,
                    itemBuilder: (context, idx) {
                      final item = _cards[idx];
                      return _buildCardTile(context, item);
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.photo_on_rectangle, size: 48, color: RuchaTheme.textSecondary),
            const SizedBox(height: 16),
            const Text('No Run Cards Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              'Finish recording a run to generate an artistic 4:5 card with your GPS route and Ethiopian ghost benchmarks.',
              textAlign: TextAlign.center,
              style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _openCardCreator(context),
              icon: const Icon(CupertinoIcons.plus, size: 16),
              label: const Text('Create Card'),
              style: ElevatedButton.styleFrom(backgroundColor: RuchaTheme.accentGreen, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardTile(BuildContext context, GalleryCardItem item) {
    LinearGradient grad;
    Color accent;
    if (item.theme == 'midnight') {
      grad = const LinearGradient(
        colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      accent = const Color(0xFF5FD6A8);
    } else if (item.theme == 'ember') {
      grad = const LinearGradient(
        colors: [Color(0xFF2B1055), Color(0xFF7597DE), Color(0xFF141E30)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      accent = const Color(0xFFF2B705);
    } else {
      grad = const LinearGradient(
        colors: [Color(0xFF1F1C2C), Color(0xFF928DAB), Color(0xFFE65C00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      accent = const Color(0xFFFF7A42);
    }

    return GestureDetector(
      onTap: () {
        final act = Activity(
          id: item.id,
          title: item.title,
          city: item.city,
          distance: item.distance,
          duration: item.duration,
          pace: item.pace,
          elevation: item.elevation,
          date: item.createdAt,
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RunCardScreen(activity: act, ghostLegend: item.ghostLegend),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: grad,
          border: Border.all(color: accent.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RUCHA',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                if (item.ghostLegend != null)
                  Text(item.ghostLegend!.icon, style: const TextStyle(fontSize: 14)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${item.distance.toStringAsFixed(1)} km',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      RuchaConstants.formatDuration(item.duration),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openCardCreator(BuildContext context) {
    final defaultAct = Activity(
      id: 'demo_card_act',
      title: 'Addis Altitude Run',
      city: 'Addis Ababa',
      distance: 7.50,
      duration: 2250,
      pace: 300.0,
      elevation: 210.0,
      date: DateTime.now(),
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RunCardScreen(activity: defaultAct, ghostLegend: LegendGhost.all[0]),
      ),
    );
  }
}

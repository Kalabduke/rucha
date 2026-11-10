import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/tracking_service.dart';
import '../models/activity.dart';
import '../widgets/osm_map_widget.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _filter = 'all'; // 'all', 'run', 'ride'

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingService>();
    final city = RuchaConstants.cities[tracking.selectedCity] ?? RuchaConstants.cities['addis']!;

    // Procedural landmark routes for the selected city
    final mockRoutes = _getCityRoutes(city);

    final filtered = mockRoutes.where((r) {
      if (_filter == 'all') return true;
      return r.type == _filter;
    }).toList();

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
            Row(
              children: [
                Text('Explore · ${city.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                const Text('አስስ', style: TextStyle(fontSize: 12, color: RuchaTheme.accentGold, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: RuchaTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RuchaTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.terrain, size: 14, color: RuchaTheme.accentGreen),
                const SizedBox(width: 6),
                Text(
                  '${city.baseEle.round()} m',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: RuchaTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: RuchaTheme.border),
              ),
              child: Row(
                children: [
                  _filterButton('all', 'All Routes'),
                  _filterButton('run', 'Runs'),
                  _filterButton('ride', 'Rides'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Embedded OpenStreetMap View
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: RuchaTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: RuchaTheme.border),
              ),
              child: OsmMapWidget(
                centerLat: city.lat,
                centerLng: city.lng,
                initialZoom: 14,
                track: filtered.isNotEmpty ? filtered.first.track : const [],
                routeColor: RuchaTheme.accentGreen,
                isInteractive: true,
                isDarkMode: true,
              ),
            ),

            const SizedBox(height: 24),

            // Popular Running Areas
            const Text(
              'POPULAR TRAINING AREAS',
              style: TextStyle(
                color: RuchaTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            _areaCard('Meskel Square Circuit', 'Asphalt · 1.2 km loop', 'Hotspot for tempo intervals & sprinters', '1,420 athletes'),
            _areaCard('Entoto Hill Ridge', 'Trail · 8.4 km climb', 'Famous high-altitude distance trails (+450m)', '890 athletes'),
            _areaCard('Bole Medhanealem Loop', 'Road · 3.5 km circuit', 'Evening road running and brisk cycling', '610 athletes'),

            const SizedBox(height: 24),

            // Routes List
            const Text(
              'COMMUNITY ROUTES',
              style: TextStyle(
                color: RuchaTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final r = filtered[idx];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: RuchaTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: RuchaTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: r.type == 'ride'
                              ? RuchaTheme.accentGreen.withOpacity(0.15)
                              : RuchaTheme.accentCoral.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          r.type == 'ride' ? Icons.directions_bike : Icons.directions_run,
                          color: r.type == 'ride' ? RuchaTheme.accentGreen : RuchaTheme.accentCoral,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(height: 3),
                            Text(
                              '${r.distance.toStringAsFixed(1)} km · +${r.elevation.round()} m elevation',
                              style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(CupertinoIcons.chevron_right, size: 16, color: RuchaTheme.textSecondary),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _filterButton(String key, String label) {
    final active = _filter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? RuchaTheme.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? RuchaTheme.textPrimary : RuchaTheme.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _areaCard(String name, String tag, String desc, String athleteCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RuchaTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: RuchaTheme.accentGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(CupertinoIcons.location_solid, color: RuchaTheme.accentGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(athleteCount, style: const TextStyle(color: RuchaTheme.accentGold, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(tag, style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Activity> _getCityRoutes(City city) {
    return [
      Activity(
        id: 'r1',
        title: '${city.name} Morning Loop',
        type: 'run',
        distance: 6.2,
        duration: 1860,
        elevation: 85,
        pace: 300,
        calories: 390,
        date: DateTime.now(),
        city: city.id,
        track: [
          TrackPoint(lat: city.lat, lng: city.lng, ele: city.baseEle, d: 0, t: 0, accuracy: 5),
          TrackPoint(lat: city.lat + 0.005, lng: city.lng + 0.007, ele: city.baseEle + 30, d: 2.1, t: 600, accuracy: 5),
          TrackPoint(lat: city.lat + 0.009, lng: city.lng + 0.003, ele: city.baseEle + 55, d: 4.5, t: 1300, accuracy: 5),
          TrackPoint(lat: city.lat, lng: city.lng, ele: city.baseEle, d: 6.2, t: 1860, accuracy: 5),
        ],
      ),
      Activity(
        id: 'r2',
        title: '${city.name} High Altitude Climb',
        type: 'ride',
        distance: 18.5,
        duration: 3200,
        elevation: 320,
        pace: 172,
        calories: 610,
        date: DateTime.now(),
        city: city.id,
        track: [
          TrackPoint(lat: city.lat, lng: city.lng, ele: city.baseEle, d: 0, t: 0, accuracy: 5),
          TrackPoint(lat: city.lat + 0.015, lng: city.lng + 0.012, ele: city.baseEle + 180, d: 9.0, t: 1600, accuracy: 5),
          TrackPoint(lat: city.lat + 0.022, lng: city.lng + 0.019, ele: city.baseEle + 320, d: 18.5, t: 3200, accuracy: 5),
        ],
      ),
    ];
  }
}

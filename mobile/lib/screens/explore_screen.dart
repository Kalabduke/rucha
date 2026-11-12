import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/activity.dart';
import '../models/popular_area.dart';
import '../services/activity_store.dart';
import '../services/api_service.dart';
import '../services/tracking_service.dart';
import '../widgets/osm_map_widget.dart';

class ExploreScreen extends StatefulWidget {
  final VoidCallback? onStartRecording;

  const ExploreScreen({super.key, this.onStartRecording});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<PopularArea> _remoteAreas = [];
  bool _loading = true;
  String? _selectedKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAreas());
  }

  Future<void> _loadAreas() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    final api = context.read<ApiService>();
    final areas = await api.fetchPopularAreas();
    if (!mounted) return;
    setState(() {
      _remoteAreas = areas;
      _loading = false;
    });
  }

  Future<void> _openGoogleMaps(PopularArea area) async {
    final launched = await launchUrl(
      Uri.parse(area.googleMapsDirectionsUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open Google Maps for ${area.name}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingService>();
    final store = context.watch<ActivityStore>();
    final city = RuchaConstants.cities[tracking.selectedCity] ??
        RuchaConstants.cities['addis']!;

    final localAreas = PopularAreaBuilder.clusterActivities(store.activities);
    final allAreas = PopularAreaBuilder.merge(_remoteAreas, localAreas);
    final nearby = allAreas.where((area) {
      return RuchaConstants.haversineDistance(
            city.lat,
            city.lng,
            area.lat,
            area.lng,
          ) <=
          60000;
    }).toList();
    final areas = nearby.isNotEmpty ? nearby : allAreas;

    PopularArea? selected;
    for (final area in areas) {
      if (area.key == _selectedKey) {
        selected = area;
        break;
      }
    }
    selected ??= areas.isNotEmpty ? areas.first : null;

    final preview = tracking.previewPosition;

    return RefreshIndicator(
      color: RuchaTheme.accentGreen,
      backgroundColor: RuchaTheme.surface,
      onRefresh: _loadAreas,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cityHeader(city),
            const SizedBox(height: 16),
            _buildMap(city, areas, selected, preview),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'POPULAR TRAINING AREAS',
                    style: TextStyle(
                      color: RuchaTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh areas',
                  onPressed: _loading ? null : _loadAreas,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          CupertinoIcons.refresh,
                          size: 18,
                          color: RuchaTheme.textSecondary,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            if (areas.isEmpty)
              Text(
                'No areas near ${city.name} yet.',
                style: const TextStyle(
                  color: RuchaTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            const SizedBox(height: 12),
            if (_loading && areas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (areas.isEmpty)
              _emptyAreas(city)
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: areas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final area = areas[index];
                  return _areaCard(area, selected?.key == area.key, preview);
                },
              ),
            const SizedBox(height: 24),
            const Text(
              'ALTITUDE CONTEXT',
              style: TextStyle(
                color: RuchaTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            _altitudeCard(city),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _cityHeader(City city) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              color: RuchaTheme.accentGreen.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              CupertinoIcons.location_solid,
              color: RuchaTheme.accentGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: RuchaTheme.surface2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: RuchaTheme.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.terrain,
                  size: 13,
                  color: RuchaTheme.accentGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  '${city.baseEle.round()} m',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(
    City city,
    List<PopularArea> areas,
    PopularArea? selected,
    TrackPoint? preview,
  ) {
    final centerLat = selected?.lat ?? preview?.lat ?? city.lat;
    final centerLng = selected?.lng ?? preview?.lng ?? city.lng;
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RuchaTheme.border),
      ),
      child: Stack(
        children: [
          OsmMapWidget(
            centerLat: centerLat,
            centerLng: centerLng,
            initialZoom: 14,
            routeColor: RuchaTheme.accentGreen,
            isInteractive: true,
            isDarkMode: true,
            currentPosition: preview, // Pulsing blue dot for user location
            markers: [
              for (final area in areas)
                OsmMapMarker(
                  lat: area.lat,
                  lng: area.lng,
                  label: area.name,
                  selected: selected?.key == area.key,
                  color: selected?.key == area.key
                      ? RuchaTheme.accentCoral
                      : RuchaTheme.accentGreen,
                  onTap: () => setState(() => _selectedKey = area.key),
                ),
            ],
          ),
          if (preview != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: Material(
                color: RuchaTheme.surface,
                borderRadius: BorderRadius.circular(12),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _selectedKey =
                          null; // Clear area selection to center on user
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: const Icon(
                      CupertinoIcons.location_fill,
                      color: RuchaTheme.accentBlue,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyAreas(City city) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RuchaTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.map_pin_ellipse,
                color: RuchaTheme.accentGold,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'The map starts with your first real run',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Start recording near ${city.name} to discover training areas.',
            style: const TextStyle(
              color: RuchaTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          if (widget.onStartRecording != null) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: widget.onStartRecording,
              icon: const Icon(CupertinoIcons.play_arrow_solid, size: 18),
              label: const Text('Record an activity'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _areaCard(
    PopularArea area,
    bool selected,
    TrackPoint? preview,
  ) {
    final distance = area.distanceFromMeters(preview?.lat, preview?.lng);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? RuchaTheme.accentGreen : RuchaTheme.border,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _selectedKey = area.key),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: RuchaTheme.accentGreen.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.map_pin_ellipse,
                  color: RuchaTheme.accentGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${area.runCount} ${area.runCount == 1 ? 'activity' : 'activities'} started here'
                      '${area.city.isNotEmpty ? ' · ${area.city}' : ''}',
                      style: const TextStyle(
                        color: RuchaTheme.accentGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      area.coordinates +
                          (distance > 0
                              ? ' · ${distance < 1000 ? '${distance.round()} m' : '${(distance / 1000).toStringAsFixed(1)} km'} away'
                              : ''),
                      style: const TextStyle(
                        color: RuchaTheme.textSecondary,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Open in Google Maps',
                onPressed: () => _openGoogleMaps(area),
                style: IconButton.styleFrom(
                  backgroundColor:
                      RuchaTheme.accentCoral.withValues(alpha: 0.14),
                  foregroundColor: RuchaTheme.accentCoral,
                ),
                icon: const Icon(Icons.directions, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _altitudeCard(City city) {
    final adjusted = RuchaConstants.seaLevelEquivalentPace(300.0, city.baseEle);
    return Container(
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
              color: RuchaTheme.accentGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.terrain,
              color: RuchaTheme.accentGreen,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${city.name} · ${city.baseEle.round()} m',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  city.tag,
                  style: const TextStyle(
                    color: RuchaTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'A 5:00/km effort here is roughly ${RuchaConstants.formatPace(adjusted)}/km at sea level. '
                  'The app adjusts pace for altitude using this city elevation.',
                  style: const TextStyle(
                    color: RuchaTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

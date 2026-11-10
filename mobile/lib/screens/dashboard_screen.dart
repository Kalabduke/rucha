import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../services/tracking_service.dart';
import '../models/activity.dart';
import '../widgets/metric_card.dart';
import 'run_card_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onStartRecording;
  final ValueChanged<int>? onNavigateTo;

  const DashboardScreen({
    super.key,
    required this.onStartRecording,
    this.onNavigateTo,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Activity> _recentActivities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = context.read<ApiService>();
    final acts = await api.fetchActivities();
    if (mounted) {
      setState(() {
        _recentActivities = acts;
        _isLoading = false;
      });
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingService>();
    final city = RuchaConstants.cities[tracking.selectedCity] ?? RuchaConstants.cities['addis']!;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: RuchaTheme.accentGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(CupertinoIcons.flame_fill, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text(RuchaConstants.appName),
          ],
        ),
        actions: [
          // City selector button
          PopupMenuButton<String>(
            initialValue: tracking.selectedCity,
            onSelected: (val) => tracking.setCity(val),
            itemBuilder: (context) => RuchaConstants.cities.values.map((c) {
              return PopupMenuItem<String>(
                value: c.id,
                child: Text('${c.name} (${c.baseEle.round()}m)'),
              );
            }).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: RuchaTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: RuchaTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.location_solid, size: 12, color: RuchaTheme.accentGreen),
                  const SizedBox(width: 4),
                  Text(
                    city.name,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Greeting Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: RuchaTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: RuchaTheme.border),
                    gradient: LinearGradient(
                      colors: [
                        RuchaTheme.surface,
                        RuchaTheme.accentGreen.withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _greeting(),
                            style: const TextStyle(
                              color: RuchaTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: RuchaTheme.surface2,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              city.tag,
                              style: const TextStyle(fontSize: 10, color: RuchaTheme.accentGold, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ready for your run today?',
                        style: TextStyle(
                          color: RuchaTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: widget.onStartRecording,
                        icon: const Icon(CupertinoIcons.play_arrow_solid, size: 18),
                        label: const Text('Start Live Track'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // RUCHA Hub: 1-click access to Gallery, Segments, Community, Challenges
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'RUCHA ATHLETE HUB',
                      style: TextStyle(
                        color: RuchaTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'ሁሉንም ክፍሎች ይመልከቱ',
                      style: TextStyle(
                        color: RuchaTheme.accentGold.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => widget.onNavigateTo?.call(4), // Gallery
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: RuchaTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: RuchaTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: RuchaTheme.accentCoral.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(CupertinoIcons.photo_on_rectangle, size: 16, color: RuchaTheme.accentCoral),
                              ),
                              const SizedBox(height: 8),
                              const Text('Run Cards', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
                              const Text('ጋለሪ ስቱዲዮ', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => widget.onNavigateTo?.call(5), // Segments
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: RuchaTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: RuchaTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: RuchaTheme.accentGreen.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.terrain, size: 16, color: RuchaTheme.accentGreen),
                              ),
                              const SizedBox(height: 8),
                              const Text('Segments', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
                              const Text('የተራራ ክፍሎች', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => widget.onNavigateTo?.call(7), // Challenges
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: RuchaTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: RuchaTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: RuchaTheme.accentGold.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(CupertinoIcons.flag_fill, size: 16, color: RuchaTheme.accentGold),
                              ),
                              const SizedBox(height: 8),
                              const Text('Prizes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
                              const Text('ውድድሮች', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => widget.onNavigateTo?.call(6), // Community
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: RuchaTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: RuchaTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(CupertinoIcons.person_3_fill, size: 16, color: Colors.blueAccent),
                              ),
                              const SizedBox(height: 8),
                              const Text('Clubs', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
                              const Text('ማህበረሰብ', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Upcoming Ethiopian Holiday Notice
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: RuchaTheme.surface2.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: RuchaTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: RuchaTheme.accentGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(CupertinoIcons.calendar, size: 18, color: RuchaTheme.accentGold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              RuchaConstants.holidays[0]['name']!,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${RuchaConstants.holidays[0]['date']} · ${RuchaConstants.holidays[0]['desc']}',
                              style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // This Week's Training Stats
                const Text(
                  'LAST 7 DAYS',
                  style: TextStyle(
                    color: RuchaTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),

                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.1,
                  children: const [
                    MetricCard(
                      label: 'Distance',
                      value: '24.8',
                      unit: 'km',
                      icon: CupertinoIcons.map_pin_ellipse,
                    ),
                    MetricCard(
                      label: 'Time',
                      value: '2:14:30',
                      unit: '',
                      icon: CupertinoIcons.clock,
                      iconColor: RuchaTheme.accentGold,
                    ),
                    MetricCard(
                      label: 'Elevation',
                      value: '+410',
                      unit: 'm',
                      icon: CupertinoIcons.arrow_up_right,
                    ),
                    MetricCard(
                      label: 'Activities',
                      value: '4',
                      unit: 'runs',
                      icon: CupertinoIcons.flame,
                      iconColor: RuchaTheme.accentCoral,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Recent Activities Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'RECENT ACTIVITIES',
                      style: TextStyle(
                        color: RuchaTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (_isLoading)
                      const CupertinoActivityIndicator(radius: 8),
                  ],
                ),
                const SizedBox(height: 10),

                if (_recentActivities.isEmpty && !_isLoading)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: RuchaTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: RuchaTheme.border),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Icon(Icons.directions_walk, size: 40, color: RuchaTheme.textSecondary),
                        const SizedBox(height: 10),
                        const Text(
                          'No activities recorded yet',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap Start Live Track to log your first Ethiopian run!',
                          style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentActivities.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final a = _recentActivities[idx];
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
                                color: a.type == 'ride'
                                    ? RuchaTheme.accentGreen.withOpacity(0.15)
                                    : RuchaTheme.accentCoral.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                a.type == 'ride' ? Icons.directions_bike : Icons.directions_run,
                                color: a.type == 'ride' ? RuchaTheme.accentGreen : RuchaTheme.accentCoral,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.title,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${a.distance.toStringAsFixed(2)} km · ${RuchaConstants.formatDuration(a.duration)} · +${a.elevation.round()}m',
                                    style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(CupertinoIcons.sparkles, color: RuchaTheme.accentGold, size: 18),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => RunCardScreen(activity: a)),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

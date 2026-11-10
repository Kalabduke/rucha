import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/challenge.dart';
import '../services/api_service.dart';
import '../core/theme.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  List<Challenge> _challenges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    final api = context.read<ApiService>();
    final list = await api.fetchChallenges();
    if (mounted) {
      setState(() {
        _challenges = list.isNotEmpty ? list : _fallbackChallenges();
        _isLoading = false;
      });
    }
  }

  List<Challenge> _fallbackChallenges() {
    return [
      Challenge(
        id: 'c1',
        title: 'Entoto Ridge Vertical KM',
        description: 'Climb 1,000 vertical meters through the eucalyptus trails of Entoto.',
        kind: 'vertical_km',
        mode: 'open',
        targetElev: 1000.0,
        prizeBirr: 5000,
      ),
      Challenge(
        id: 'c2',
        title: 'Bishoftu Crater Lakes 10K',
        description: 'Loop the rim of Lake Bishoftu in under 48 minutes.',
        kind: 'time_trial',
        mode: 'open',
        targetKm: 10.0,
        targetTime: 2880,
        prizeBirr: 3500,
      ),
      Challenge(
        id: 'c3',
        title: 'Meskel Square 5K Sprint Duel',
        description: 'Head-to-head sprint duel on the Meskel Square circuit.',
        kind: 'head_to_head',
        mode: 'head_to_head',
        targetKm: 5.0,
        prizeBirr: 2000,
      ),
      Challenge(
        id: 'c4',
        title: 'Adwa 30-Day Consistency Streak',
        description: 'Record an activity every day for 30 consecutive days.',
        kind: 'consistency_30',
        mode: 'goal',
        prizeBirr: 10000,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenges & Duels'),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : RefreshIndicator(
              onRefresh: _loadChallenges,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _challenges.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final c = _challenges[idx];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: RuchaTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: RuchaTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: RuchaTheme.surface2,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                c.kind.toUpperCase().replaceAll('_', ' '),
                                style: const TextStyle(
                                  color: RuchaTheme.accentGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (c.prizeBirr > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: RuchaTheme.accentGold.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Br ${c.prizeBirr}',
                                  style: const TextStyle(
                                    color: RuchaTheme.accentGold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          c.title,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.description,
                          style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Joined "${c.title}"!')),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: const Text('Join Challenge', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

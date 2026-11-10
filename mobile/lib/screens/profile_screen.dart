import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Athlete Profile'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.settings),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings & Privacy consent up to date (v2026-11-07)')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: RuchaTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: RuchaTheme.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: RuchaTheme.accentGreen,
                    child: const Text(
                      'A',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Athlete', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text('Addis Ababa, Ethiopia · Altitude 2,355m', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // All-Time Summary Stats
            Row(
              children: [
                _statTile('TOTAL DISTANCE', '312.4', 'km'),
                const SizedBox(width: 10),
                _statTile('TOTAL CLIMB', '4,820', 'm'),
                const SizedBox(width: 10),
                _statTile('ACTIVITIES', '42', 'runs'),
              ],
            ),

            const SizedBox(height: 24),

            // Weekly Training Volume (Last 7 Weeks)
            const Text(
              'WEEKLY TRAINING VOLUME',
              style: TextStyle(
                color: RuchaTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: RuchaTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: RuchaTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Weekly Mileage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text('Target: 30 km/wk', style: TextStyle(color: RuchaTheme.accentGold, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _bar('W1', 18, 50),
                      _bar('W2', 24, 70),
                      _bar('W3', 20, 58),
                      _bar('W4', 32, 95),
                      _bar('W5', 28, 80),
                      _bar('W6', 15, 42),
                      _bar('Now', 25, 75, isCurrent: true),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Personal Records (PRs)
            const Text(
              'PERSONAL RECORDS (PRS)',
              style: TextStyle(
                color: RuchaTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: RuchaTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: RuchaTheme.border),
              ),
              child: Column(
                children: [
                  _prRow('Fastest 1 km', '3:42', 'Nov 2026 · Meskel Square'),
                  _divider(),
                  _prRow('Fastest 5 km', '19:15', 'Oct 2026 · Bishoftu Lake'),
                  _divider(),
                  _prRow('Fastest 10 km', '41:08', 'Sep 2026 · Entoto Trail'),
                  _divider(),
                  _prRow('Longest Activity', '21.1 km', 'Half Marathon · Addis Ababa'),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  static Widget _statTile(String label, String value, String unit) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: RuchaTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: RuchaTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 8.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(width: 3),
                Text(unit, style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _bar(String label, int km, double height, {bool isCurrent = false}) {
    return Column(
      children: [
        Text('$km', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isCurrent ? RuchaTheme.accentGreen : RuchaTheme.textSecondary)),
        const SizedBox(height: 4),
        Container(
          width: 14,
          height: height,
          decoration: BoxDecoration(
            color: isCurrent ? RuchaTheme.accentGreen : RuchaTheme.surface2,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: RuchaTheme.textSecondary)),
      ],
    );
  }

  static Widget _prRow(String title, String time, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.rosette, color: RuchaTheme.accentGold, size: 18),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(detail, style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
          Text(time, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: RuchaTheme.accentGold)),
        ],
      ),
    );
  }

  static Widget _divider() {
    return const Divider(height: 1, color: RuchaTheme.border);
  }
}

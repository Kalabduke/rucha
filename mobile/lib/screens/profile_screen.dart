import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/user.dart';
import '../services/activity_store.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final store = context.watch<ActivityStore>();
    final user = auth.currentUser;
    final isAuthed = auth.isAuthenticated && user != null;
    final stats = store.allTimeStats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isAuthed) _buildAthleteCard(user, auth) else _buildGuestCard(context, auth),
          const SizedBox(height: 16),
          Row(
            children: [
              _statTile('TOTAL DISTANCE', stats.distanceKm.toStringAsFixed(1), 'km'),
              const SizedBox(width: 10),
              _statTile('TOTAL CLIMB', stats.elevationGain.round().toString(), 'm'),
              const SizedBox(width: 10),
              _statTile('ACTIVITIES', '${stats.activityCount}', stats.activityCount == 1 ? 'run' : 'runs'),
            ],
          ),
          const SizedBox(height: 24),
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
          _buildWeeklyChart(store),
          const SizedBox(height: 24),
          const Text(
            'PERSONAL RECORDS (ALTITUDE ADJUSTED)',
            style: TextStyle(
              color: RuchaTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          _buildBestEfforts(store),
          const SizedBox(height: 24),
          // Settings row — taps into the dedicated Settings screen
          Container(
            decoration: BoxDecoration(
              color: RuchaTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: RuchaTheme.border),
            ),
            child: ListTile(
              leading: const Icon(
                CupertinoIcons.settings,
                color: RuchaTheme.textSecondary,
                size: 22,
              ),
              title: const Text(
                'Settings',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: const Text(
                'Language, preferences, recording',
                style: TextStyle(fontSize: 11, color: RuchaTheme.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18, color: RuchaTheme.textSecondary),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        leading: const BackButton(),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'RUCHA / SETTINGS',
                              style: TextStyle(
                                color: RuchaTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              'Make it yours',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: RuchaTheme.textPrimary,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                        bottom: PreferredSize(
                          preferredSize: const Size.fromHeight(3.0),
                          child: Row(
                            children: [
                              Expanded(child: Container(height: 3, color: RuchaTheme.accentGreen)),
                              Expanded(child: Container(height: 3, color: RuchaTheme.accentGold)),
                              Expanded(child: Container(height: 3, color: RuchaTheme.accentRed)),
                            ],
                          ),
                        ),
                      ),
                      body: const SettingsScreen(),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RuchaTheme.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: RuchaTheme.border),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.shield_lefthalf_fill,
                  color: RuchaTheme.accentGreen,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Privacy first · private by default',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Activities are private by default. Local-mode runs stay on this '
                        'device until you connect a RUCHA server. '
                        'Terms & Privacy v${auth.config.privacyVersion}.',
                        style: TextStyle(
                          color: RuchaTheme.textSecondary.withValues(alpha: 0.9),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isAuthed || auth.isGuest) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context, auth),
              icon: const Icon(
                CupertinoIcons.square_arrow_right,
                size: 18,
                color: RuchaTheme.accentRed,
              ),
              label: Text(
                auth.isGuest ? 'Exit guest mode' : 'Sign out',
                style: const TextStyle(
                  color: RuchaTheme.accentRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: RuchaTheme.accentRed.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAthleteCard(User user, AuthService auth) {
    final name = user.displayName.isNotEmpty ? user.displayName : user.username;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final providers = <String>{
      ...user.providers,
      if (auth.isLocalAccount) 'local',
    }.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RuchaTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: RuchaTheme.accentGreen,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      style: const TextStyle(
                        color: RuchaTheme.accentGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${user.city}, Ethiopia',
                      style: const TextStyle(
                        color: RuchaTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: RuchaTheme.border, height: 1),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text(
                  'Connected: ',
                  style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 11),
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final provider in providers) _providerChip(provider),
                    if (providers.isEmpty) _providerChip('account'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _providerChip(String provider) {
    final isTelegram = provider == 'telegram';
    final isLocal = provider == 'local';
    final color = isTelegram
        ? const Color(0xFF2AABEE)
        : (isLocal ? RuchaTheme.accentGold : RuchaTheme.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        isLocal ? 'ON THIS DEVICE' : provider.toUpperCase(),
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Widget _buildGuestCard(BuildContext context, AuthService auth) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RuchaTheme.accentGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: RuchaTheme.surface2,
                child: const Icon(
                  CupertinoIcons.person_fill,
                  color: RuchaTheme.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.isGuest ? 'Guest athlete' : 'Athlete profile',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      auth.isGuest
                          ? 'Runs are saved on this device. Create an account to keep them synced.'
                          : 'Sign in to sync runs, earn trophies and join clubs.',
                      style: const TextStyle(
                        color: RuchaTheme.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AuthScreen(initialIsLogin: false)),
            ),
            icon: const Icon(CupertinoIcons.sparkles, size: 18),
            label: const Text('Sign in or create account'),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Local account or Telegram when the backend is connected',
              style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(ActivityStore store) {
    final weeks = store.weeklyVolume();
    final maxDistance = weeks.fold<double>(0, (value, week) => value > week.distanceKm ? value : week.distanceKm);
    final thisWeek = weeks.isEmpty ? 0.0 : weeks.last.distanceKm;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly distance',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              Text(
                '${thisWeek.toStringAsFixed(1)} km this week',
                style: const TextStyle(
                  color: RuchaTheme.accentGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (maxDistance <= 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  'Record a run to start your weekly chart.',
                  style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              height: 132,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < weeks.length; i++)
                    _bar(
                      i == weeks.length - 1 ? 'Now' : weeks[i].label,
                      weeks[i].distanceKm,
                      weeklyBarHeight(weeks[i].distanceKm, maxDistance),
                      isCurrent: i == weeks.length - 1,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bar(String label, double km, double height, {bool isCurrent = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          km <= 0 ? '0' : km.toStringAsFixed(km >= 10 ? 0 : 1),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: isCurrent ? RuchaTheme.accentGreen : RuchaTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 15,
          height: height,
          decoration: BoxDecoration(
            color: isCurrent ? RuchaTheme.accentGreen : RuchaTheme.surfaceLight,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, color: RuchaTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildBestEfforts(ActivityStore store) {
    final efforts = store.bestEfforts;
    if (efforts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: RuchaTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RuchaTheme.border),
        ),
        child: const Column(
          children: [
            Icon(CupertinoIcons.rosette, color: RuchaTheme.textSecondary, size: 32),
            SizedBox(height: 10),
            Text(
              'No best efforts yet',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'Record a GPS run of at least 1 km to set your first personal record.',
              textAlign: TextAlign.center,
              style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RuchaTheme.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < efforts.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: RuchaTheme.border),
            _prRow(
              efforts[i].label,
              formatEffortSeconds(efforts[i].seconds),
              efforts[i].activityTitle,
            ),
          ],
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AuthService auth) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: RuchaTheme.surface,
        title: Text(auth.isGuest ? 'Exit guest mode?' : 'Sign out?'),
        content: Text(
          auth.isGuest
              ? 'Your activities remain saved on this device. You can create an account later.'
              : 'You can sign back in with your username and password. Local activities remain on this device.',
          style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              auth.logout();
            },
            child: Text(
              auth.isGuest ? 'Exit' : 'Sign out',
              style: const TextStyle(color: RuchaTheme.accentRed),
            ),
          ),
        ],
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
            Text(
              label,
              style: const TextStyle(
                color: RuchaTheme.textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: const TextStyle(
                    color: RuchaTheme.textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _prRow(String title, String time, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(CupertinoIcons.rosette, color: RuchaTheme.accentGold, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RuchaTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            time,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: RuchaTheme.accentGold,
            ),
          ),
        ],
      ),
    );
  }
}

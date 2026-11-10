import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final isAuthed = auth.isAuthenticated && user != null;

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
                Text('Athlete Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(width: 8),
                Text('መገለጫ', style: TextStyle(fontSize: 12, color: RuchaTheme.accentGold, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          if (isAuthed)
            IconButton(
              icon: const Icon(CupertinoIcons.square_arrow_right, color: RuchaTheme.accentRed),
              tooltip: 'Sign Out',
              onPressed: () => _confirmSignOut(context, auth),
            )
          else
            TextButton.icon(
              icon: const Icon(CupertinoIcons.person_crop_circle_badge_plus, size: 18, color: RuchaTheme.accentGreen),
              label: const Text('Sign In', style: TextStyle(color: RuchaTheme.accentGreen, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AuthScreen(initialIsLogin: true)),
              ),
            ),
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
            // User Card or Guest Sign In Banner
            if (isAuthed)
              _buildAthleteCard(context, user)
            else
              _buildGuestSignInCard(context),

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
                      Text('Weekly Distance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text('48.6 km this week', style: TextStyle(color: RuchaTheme.accentGreen, fontWeight: FontWeight.w800, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _bar('W38', 34, 60),
                      _bar('W39', 42, 75),
                      _bar('W40', 28, 50),
                      _bar('W41', 52, 90),
                      _bar('W42', 45, 80),
                      _bar('W43', 39, 70),
                      _bar('Now', 49, 88, isCurrent: true),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Best Efforts / Personal Records (Addis High Altitude)
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

            Container(
              decoration: BoxDecoration(
                color: RuchaTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: RuchaTheme.border),
              ),
              child: Column(
                children: [
                  _prRow('1 km', '3:22', 'Meskel Square Flat Track'),
                  _divider(),
                  _prRow('5 km', '17:48', 'Bole Medhane Alem Loop'),
                  _divider(),
                  _prRow('10 km', '38:12', 'Entoto Ridge Climb'),
                  _divider(),
                  _prRow('Half Marathon', '1:24:05', 'Great Ethiopian Run Course'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Ethiopian Runner Badge & Legal Note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: RuchaTheme.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: RuchaTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.shield_lefthalf_fill, color: RuchaTheme.accentGreen, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Privacy First · Private by Default', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 3),
                        Text(
                          'Activities are private by default. Only friends you approve can view shared runs. Terms & Privacy v2026-11-07.',
                          style: TextStyle(color: RuchaTheme.textSecondary.withOpacity(0.8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (isAuthed) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _confirmSignOut(context, auth),
                icon: const Icon(CupertinoIcons.square_arrow_right, size: 18, color: RuchaTheme.accentRed),
                label: const Text('Sign Out', style: TextStyle(color: RuchaTheme.accentRed, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: RuchaTheme.accentRed.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAthleteCard(BuildContext context, dynamic user) {
    final name = user.displayName.isNotEmpty ? user.displayName : user.username;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final providers = user.providers as List<String>;

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
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('@${user.username}', style: const TextStyle(color: RuchaTheme.accentGreen, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${user.city}, Ethiopia · Altitude 2,355m', style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (providers.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: RuchaTheme.border, height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Connected: ', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 11)),
                for (final p in providers) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: p == 'telegram' ? const Color(0xFF2AABEE).withOpacity(0.2) : RuchaTheme.surface2,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: p == 'telegram' ? const Color(0xFF2AABEE).withOpacity(0.5) : RuchaTheme.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (p == 'telegram')
                          const Icon(CupertinoIcons.paperplane_fill, size: 10, color: Color(0xFF2AABEE))
                        else if (p == 'google')
                          const Icon(CupertinoIcons.globe, size: 10, color: Colors.white)
                        else
                          const Icon(Icons.apple, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          p.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: p == 'telegram' ? const Color(0xFF2AABEE) : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuestSignInCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RuchaTheme.accentGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: RuchaTheme.surface2,
                child: const Icon(CupertinoIcons.person_fill, color: RuchaTheme.textSecondary, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Athlete Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Sync runs, earn trophies, & join clubs', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12)),
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
            label: const Text('Sign In or Create Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: RuchaTheme.accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Supports Telegram, Google, Apple ID & Username',
              style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AuthService auth) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of RUCHA?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              auth.logout();
            },
            child: const Text('Sign Out'),
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
            Text(label, style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
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

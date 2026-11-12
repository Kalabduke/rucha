import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../widgets/osm_map_widget.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final auth = context.watch<AuthService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Account ────────────────────────────────────────────────
          _SectionHeader(label: 'YOUR RUCHA ACCOUNT'),
          _AccountTile(auth: auth),
          const SizedBox(height: 20),

          // ── Language ───────────────────────────────────────────────
          _SectionHeader(label: 'LANGUAGE'),
          _LanguagePicker(settings: settings),
          const SizedBox(height: 20),

          // ── Preferences ────────────────────────────────────────────
          _SectionHeader(label: 'PREFERENCES'),
          _SettingsCard(
            children: [
              _ToggleTile(
                title: 'Ethiopian calendar',
                subtitle: 'Gregorian dates by default',
                value: settings.ethiopianCalendar,
                onChanged: settings.setEthiopianCalendar,
              ),
              const _Divider(),
              _ToggleTile(
                title: 'Geez numerals',
                subtitle: 'Western digits by default',
                value: settings.geezNumerals,
                onChanged: settings.setGeezNumerals,
              ),
              const _Divider(),
              _ToggleTile(
                title: 'Data saver',
                subtitle: 'Smaller maps. Less mobile data.',
                value: settings.dataSaver,
                onChanged: settings.setDataSaver,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Recording ──────────────────────────────────────────────
          _SectionHeader(label: 'RECORDING'),
          _SettingsCard(
            children: [
              _ToggleTile(
                title: 'Auto-pause',
                subtitle: 'Pause when you stop moving',
                value: settings.autoPause,
                onChanged: settings.setAutoPause,
              ),
              const _Divider(),
              _OfflineMapsTile(),
            ],
          ),
          const SizedBox(height: 20),

          // ── Footer ─────────────────────────────────────────────────
          const Text(
            'RUCHA · Made for the miles ahead.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RuchaTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: RuchaTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RuchaTheme.border),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1, color: RuchaTheme.border, indent: 16, endIndent: 16);
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 12),
      ),
      value: value,
      activeColor: RuchaTheme.accentGreen,
      onChanged: onChanged,
    );
  }
}

class _OfflineMapsTile extends StatefulWidget {
  @override
  State<_OfflineMapsTile> createState() => _OfflineMapsTileState();
}

class _OfflineMapsTileState extends State<_OfflineMapsTile> {
  int _usedBytes = 0;
  static const int _maxBytes = 200 * 1024 * 1024; // 200 MB
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final bytes = await OsmTileCache.cacheSize();
    if (!mounted) return;
    setState(() => _usedBytes = bytes);
  }

  Future<void> _clear() async {
    setState(() => _clearing = true);
    await OsmTileCache.purgeExpired();
    await _refresh();
    if (!mounted) return;
    setState(() => _clearing = false);
  }

  String _fmtMb(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final fraction = (_usedBytes / _maxBytes).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Offline maps',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              Text(
                '${_fmtMb(_usedBytes)} of ${_fmtMb(_maxBytes)} used',
                style: const TextStyle(
                  color: RuchaTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: RuchaTheme.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(RuchaTheme.accentGreen),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '30-day cache · tiles saved while browsing',
                style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 11),
              ),
              if (_usedBytes > 0)
                GestureDetector(
                  onTap: _clearing ? null : _clear,
                  child: Text(
                    _clearing ? 'Clearing…' : 'Clear expired',
                    style: const TextStyle(
                      color: RuchaTheme.accentGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final AuthService auth;

  const _AccountTile({required this.auth});

  @override
  Widget build(BuildContext context) {
    final isAuthed = auth.isAuthenticated && auth.currentUser != null;
    final user = auth.currentUser;

    return _SettingsCard(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: RuchaTheme.surface2,
            child: Icon(
              isAuthed ? CupertinoIcons.person_fill : CupertinoIcons.person,
              color:
                  isAuthed ? RuchaTheme.accentGreen : RuchaTheme.textSecondary,
              size: 20,
            ),
          ),
          title: Text(
            isAuthed
                ? (user!.displayName.isNotEmpty
                    ? user.displayName
                    : user.username)
                : 'Sign in with your +251 phone number',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color:
                  isAuthed ? RuchaTheme.textPrimary : RuchaTheme.textSecondary,
            ),
          ),
          subtitle: isAuthed
              ? Text(
                  '@${user!.username}',
                  style: const TextStyle(
                    color: RuchaTheme.accentGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
          trailing: isAuthed
              ? TextButton(
                  onPressed: () => _confirmSignOut(context, auth),
                  child: const Text(
                    'Sign out',
                    style: TextStyle(color: RuchaTheme.accentRed, fontSize: 12),
                  ),
                )
              : const Icon(Icons.chevron_right,
                  size: 18, color: RuchaTheme.textSecondary),
          onTap: isAuthed
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                },
        ),
      ],
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
              ? 'Your activities remain saved on this device.'
              : 'Your local activities stay on this device.',
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
}

class _LanguagePicker extends StatelessWidget {
  final SettingsService settings;

  const _LanguagePicker({required this.settings});

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _LangChip(
                label: 'English',
                selected: settings.language == 'en',
                onTap: () => settings.setLanguage('en'),
              ),
              const SizedBox(width: 4),
              _LangChip(
                label: 'አማርኛ',
                selected: settings.language == 'am',
                onTap: () => settings.setLanguage('am'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? RuchaTheme.accentGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : RuchaTheme.textSecondary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

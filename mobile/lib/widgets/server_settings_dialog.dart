import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';

Future<void> showServerSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const ServerSettingsDialog(),
  );
}

class ServerSettingsDialog extends StatefulWidget {
  const ServerSettingsDialog({super.key});

  @override
  State<ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<ServerSettingsDialog> {
  late final TextEditingController _controller;
  bool _working = false;
  String? _localError;

  static const _presets = <({String label, String url})>[
    (label: 'RUCHA (Fly.io)', url: 'https://rucha-fitness.fly.dev/api'),
    (label: 'Android emulator', url: 'http://10.0.2.2:8081/api'),
    (label: 'Linux / desktop', url: 'http://localhost:8081/api'),
  ];

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _controller = TextEditingController(text: auth.baseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _saveAndTest({required bool closeOnSuccess}) async {
    final auth = context.read<AuthService>();
    setState(() {
      _working = true;
      _localError = null;
    });

    try {
      await auth.setBaseUrl(_controller.text);
      _controller.text = auth.baseUrl;
      final online = await auth.testConnection();
      if (!mounted) return online;
      setState(() {
        _working = false;
        _localError = online ? null : auth.serverMessage;
      });
      if (online && closeOnSuccess && mounted) {
        Navigator.of(context).pop();
      }
      return online;
    } on FormatException catch (e) {
      if (!mounted) return false;
      setState(() {
        _working = false;
        _localError = e.message;
      });
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final message = _localError ?? auth.serverMessage;

    return AlertDialog(
      backgroundColor: RuchaTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.dns_rounded, color: RuchaTheme.accentGreen, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Server settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'API base URL',
                  hintText: 'https://example.com/api',
                  prefixIcon: Icon(Icons.link_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'QUICK PRESETS',
                style: TextStyle(
                  color: RuchaTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              for (final preset in _presets) ...[
                InkWell(
                  onTap: _working
                      ? null
                      : () => setState(() {
                            _controller.text = preset.url;
                            _localError = null;
                          }),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 7),
                    decoration: BoxDecoration(
                      color: _controller.text.trim() == preset.url
                          ? RuchaTheme.accentGreen.withValues(alpha: 0.12)
                          : RuchaTheme.surface2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _controller.text.trim() == preset.url
                            ? RuchaTheme.accentGreen.withValues(alpha: 0.55)
                            : RuchaTheme.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preset.url,
                          style: const TextStyle(
                            color: RuchaTheme.accentGold,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: (auth.serverOnline
                          ? RuchaTheme.accentGreen
                          : (message.contains('not checked')
                              ? RuchaTheme.surface2
                              : RuchaTheme.accentRed))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (auth.serverOnline
                            ? RuchaTheme.accentGreen
                            : RuchaTheme.border)
                        .withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      auth.serverOnline
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      size: 17,
                      color: auth.serverOnline
                          ? RuchaTheme.accentGreen
                          : RuchaTheme.accentGold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _working ? 'Checking the server…' : message,
                        style: const TextStyle(fontSize: 11, height: 1.4),
                      ),
                    ),
                    if (_working)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _working ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed:
              _working ? null : () => _saveAndTest(closeOnSuccess: false),
          child: const Text('Test'),
        ),
        FilledButton(
          onPressed: _working ? null : () => _saveAndTest(closeOnSuccess: true),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

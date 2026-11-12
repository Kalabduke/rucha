import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/media_share_service.dart';
import '../widgets/rucha_logo.dart';

enum AuthViewStep { form, telegramCode, completeProfile }

class AuthScreen extends StatefulWidget {
  final bool initialIsLogin;
  final bool isGate;

  const AuthScreen({
    super.key,
    this.initialIsLogin = false,
    this.isGate = false,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isLogin;
  AuthViewStep _step = AuthViewStep.form;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _tgCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _acceptConsent = false;
  bool _busy = false;
  String _errorMessage = '';

  Timer? _usernameDebounce;
  String _usernameStatus = '';
  String _usernameReason = '';

  String _tgLoginId = '';
  String _tgBotName = '';
  String _tgLink = '';

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
    _usernameController.addListener(_onUsernameChanged);

    final auth = context.read<AuthService>();

    // Kick off a server check immediately so Telegram shows up without delay.
    if (!auth.serverOnline && !auth.isCheckingServer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) auth.fetchConfig();
      });
    }

    final user = auth.currentUser;
    if (user != null && !user.profileComplete) {
      _step = AuthViewStep.completeProfile;
      if (user.displayName.isNotEmpty && user.displayName != 'New Athlete') {
        _displayNameController.text = user.displayName;
      }
      _phoneController.text = user.phoneNumber;
    }
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    _tgCodeController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    if (_step == AuthViewStep.telegramCode) return;
    if (_isLogin && _step == AuthViewStep.form) return;

    _usernameDebounce?.cancel();
    final text = _usernameController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _usernameStatus = '';
        _usernameReason = '';
      });
      return;
    }

    setState(() {
      _usernameStatus = 'checking';
      _usernameReason = 'Checking…';
    });

    _usernameDebounce = Timer(const Duration(milliseconds: 400), () async {
      final auth = context.read<AuthService>();
      final result = await auth.checkUsername(text);
      if (!mounted || _usernameController.text.trim() != text) return;
      setState(() {
        if (result['available'] == true) {
          _usernameStatus = 'available';
          _usernameReason = 'Available';
        } else {
          _usernameStatus = 'taken';
          _usernameReason = result['reason']?.toString() ?? 'Unavailable';
        }
      });
    });
  }

  void _switchMode(bool login) {
    setState(() {
      _isLogin = login;
      _errorMessage = '';
      _usernameStatus = '';
      _usernameReason = '';
    });
  }

  void _finishAuthIfNeeded(AuthResult result) {
    if (!result.success || result.user == null) {
      setState(() => _errorMessage = result.error ?? 'Authentication failed.');
      return;
    }
    final user = result.user!;
    if (!user.profileComplete) {
      setState(() {
        _step = AuthViewStep.completeProfile;
        _displayNameController.text =
            user.displayName == 'New Athlete' ? '' : user.displayName;
        _phoneController.text = user.phoneNumber;
        _usernameController.clear();
        _passwordController.clear();
        _errorMessage = '';
      });
      return;
    }
    if (!widget.isGate) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _submitCreateAccount() async {
    final auth = context.read<AuthService>();
    final displayName = _displayNameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (displayName.isEmpty) {
      setState(() => _errorMessage = 'Enter your athlete name.');
      return;
    }
    final usernameError = auth.validateUsername(username);
    if (usernameError != null) {
      setState(() => _errorMessage = usernameError);
      return;
    }
    if (_usernameStatus == 'taken') {
      setState(() =>
          _errorMessage = 'That username is already taken. Choose another.');
      return;
    }
    if (password.length < auth.minPassword) {
      setState(() => _errorMessage =
          'Password must be at least ${auth.minPassword} characters.');
      return;
    }
    if (!_acceptConsent) {
      setState(() => _errorMessage =
          'Accept the Privacy Policy and Terms of Use to continue.');
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = '';
    });
    final result = await auth.register(
      username,
      password,
      displayName,
      phoneNumber: _phoneController.text.trim(),
      acceptPrivacy: true,
      acceptTerms: true,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _finishAuthIfNeeded(result);
  }

  Future<void> _submitLogin() async {
    final auth = context.read<AuthService>();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter your username and password.');
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = '';
    });
    final result = await auth.login(username, password);
    if (!mounted) return;
    setState(() => _busy = false);
    _finishAuthIfNeeded(result);
  }

  Future<void> _submitCompleteProfile() async {
    final auth = context.read<AuthService>();
    final displayName = _displayNameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (displayName.isEmpty) {
      setState(() => _errorMessage = 'Enter your athlete name.');
      return;
    }
    final usernameError = auth.validateUsername(username);
    if (usernameError != null) {
      setState(() => _errorMessage = usernameError);
      return;
    }
    if (_usernameStatus == 'taken') {
      setState(() =>
          _errorMessage = 'That username is already taken. Choose another.');
      return;
    }
    if (password.length < auth.minPassword) {
      setState(() => _errorMessage =
          'Password must be at least ${auth.minPassword} characters.');
      return;
    }
    if (!_acceptConsent) {
      setState(() => _errorMessage =
          'Accept the Privacy Policy and Terms of Use to continue.');
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = '';
    });
    final result = await auth.completeProfile(
      username,
      password,
      displayName,
      phoneNumber: _phoneController.text.trim(),
      acceptPrivacy: true,
      acceptTerms: true,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _finishAuthIfNeeded(result);
  }

  Future<void> _startTelegram() async {
    final auth = context.read<AuthService>();
    if (!auth.telegramAvailable) {
      setState(() {
        _errorMessage = auth.serverOnline
            ? 'Telegram sign-in is not configured on this server. Use a local account.'
            : 'Telegram sign-in needs the RUCHA Go backend. Open Server settings to connect it.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = '';
    });
    try {
      final result = await auth.telegramStart();
      if (!mounted) return;
      final bot = result.bot.isNotEmpty ? result.bot : auth.config.telegramBot;
      setState(() {
        _busy = false;
        _tgLoginId = result.loginId;
        _tgBotName = bot;
        _tgLink = result.link.isNotEmpty
            ? result.link
            : 'https://t.me/$bot?start=${result.loginId}';
        _step = AuthViewStep.telegramCode;
      });

      final opened = await MediaShareService.openTelegram(
        bot: bot,
        start: result.loginId,
      );
      if (!opened) {
        try {
          await launchUrl(Uri.parse(_tgLink),
              mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _verifyTelegramCode() async {
    final code = _tgCodeController.text.trim();
    if (code.length != 6) {
      setState(() =>
          _errorMessage = 'Enter the 6-digit code sent by the RUCHA bot.');
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = '';
    });
    final result =
        await context.read<AuthService>().telegramVerify(_tgLoginId, code);
    if (!mounted) return;
    setState(() => _busy = false);
    _finishAuthIfNeeded(result);
  }

  Future<void> _continueAsGuest() async {
    await context.read<AuthService>().continueAsGuest();
    if (!mounted) return;
    if (!widget.isGate) Navigator.of(context).pop(true);
  }

  Future<void> _useAnotherAccount() async {
    await context.read<AuthService>().logout();
    if (!mounted) return;
    setState(() {
      _step = AuthViewStep.form;
      _isLogin = false;
      _errorMessage = '';
      _usernameController.clear();
      _passwordController.clear();
      _displayNameController.clear();
      _phoneController.clear();
      _tgCodeController.clear();
      _usernameStatus = '';
      _usernameReason = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: RuchaTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.isGate
            ? null
            : IconButton(
                icon: const Icon(CupertinoIcons.xmark,
                    color: RuchaTheme.textSecondary),
                onPressed: () => Navigator.of(context).pop(false),
              ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RuchaLogo(size: 26, showText: false, showFlag: false),
            SizedBox(width: 8),
            Text(
              'RUCHA',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 16),
            ),
          ],
        ),
        centerTitle: true,
        actions: const [],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage.isNotEmpty) _buildErrorBanner(),
              if (_step == AuthViewStep.telegramCode)
                _buildTelegramCodeView()
              else if (_step == AuthViewStep.completeProfile)
                _buildCompleteProfileView(auth)
              else
                _buildMainForm(auth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: RuchaTheme.accentRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RuchaTheme.accentRed.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: RuchaTheme.accentRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(
                  color: RuchaTheme.textPrimary, fontSize: 13, height: 1.4),
            ),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.clear,
                size: 14, color: RuchaTheme.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _errorMessage = ''),
          ),
        ],
      ),
    );
  }

  Widget _buildMainForm(AuthService auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Center(
            child: RuchaLogo(size: 64, showText: true, showFlag: true)),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: RuchaTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RuchaTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                  child: _modeButton(
                      'Create account', !_isLogin, () => _switchMode(false))),
              Expanded(
                  child: _modeButton(
                      'Sign in', _isLogin, () => _switchMode(true))),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_isLogin) _buildSignInForm(auth) else _buildCreateForm(auth),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _busy ? null : _continueAsGuest,
          icon: const Icon(CupertinoIcons.device_phone_portrait, size: 17),
          label: const Text(
            'Continue without an account · saved on this device',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  Widget _modeButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? RuchaTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : RuchaTheme.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCreateForm(AuthService auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: RuchaTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RuchaTheme.border),
            gradient: LinearGradient(
              colors: [
                RuchaTheme.surface,
                RuchaTheme.accentGreen.withValues(alpha: 0.07)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(CupertinoIcons.sparkles,
                      size: 17, color: RuchaTheme.accentGold),
                  SizedBox(width: 8),
                  Text(
                    'CREATE YOUR ATHLETE ACCOUNT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: RuchaTheme.accentGold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Run anywhere. Keep every kilometre.',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
              SizedBox(height: 5),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _label('Athlete name'),
        const SizedBox(height: 6),
        TextField(
          controller: _displayNameController,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: const InputDecoration(
            prefixIcon: Icon(CupertinoIcons.person, size: 18),
            hintText: 'e.g. Kenenisa Bekele',
          ),
        ),
        const SizedBox(height: 14),
        _usernameLabel(),
        const SizedBox(height: 6),
        _usernameField(hint: 'letters, numbers and _ (3-20)'),
        const SizedBox(height: 14),
        _label('Phone number (optional)'),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: const InputDecoration(
            prefixIcon: Icon(CupertinoIcons.phone, size: 18),
            hintText: '+251 9… or 09…',
            helperText: 'Used only for account recovery and race results.',
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: 14),
        _label('Password'),
        const SizedBox(height: 6),
        _passwordField(hint: 'at least ${auth.minPassword} characters'),
        const SizedBox(height: 16),
        _consentRow(auth),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: _busy ? null : _submitCreateAccount,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create account & start training'),
        ),
        const SizedBox(height: 16),
        _orDivider(),
        const SizedBox(height: 14),
        _telegramSection(auth),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => _switchMode(true),
            child: const Text('Already have an account? Sign in →'),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInForm(AuthService auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Username'),
        const SizedBox(height: 6),
        TextField(
          controller: _usernameController,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: const InputDecoration(
            prefixIcon: Icon(CupertinoIcons.at, size: 18),
            hintText: 'Your RUCHA username',
          ),
        ),
        const SizedBox(height: 14),
        _label('Password'),
        const SizedBox(height: 6),
        _passwordField(hint: 'Your password'),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _busy ? null : _submitLogin,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Sign in to RUCHA'),
        ),
        const SizedBox(height: 16),
        _orDivider(),
        const SizedBox(height: 14),
        _telegramSection(auth),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => _switchMode(false),
            child: const Text('New to RUCHA? Create an account →'),
          ),
        ),
      ],
    );
  }

  Widget _buildTelegramCodeView() {
    final bot = _tgBotName.isNotEmpty ? _tgBotName : 'the RUCHA bot';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _step = AuthViewStep.form;
              _errorMessage = '';
            }),
            icon: const Icon(CupertinoIcons.arrow_left, size: 16),
            label: const Text('Back'),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: RuchaTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RuchaTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2AABEE).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'TELEGRAM VERIFICATION',
                  style: TextStyle(
                    color: Color(0xFF2AABEE),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Check @$bot',
                style:
                    const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Open @$bot in Telegram, press Start, and send the /start command. '
                'The bot will reply with a 6-digit code.',
                style: const TextStyle(
                  color: RuchaTheme.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final opened = await MediaShareService.openTelegram(
                    bot: bot,
                    start: _tgLoginId,
                  );
                  if (!opened && _tgLink.isNotEmpty) {
                    try {
                      await launchUrl(Uri.parse(_tgLink),
                          mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  }
                },
                icon: const Icon(CupertinoIcons.paperplane_fill, size: 18),
                label: Text('Open @$bot in Telegram'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2AABEE),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _label('Enter the 6-digit code'),
        const SizedBox(height: 8),
        TextField(
          controller: _tgCodeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 10,
          ),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '······',
            hintStyle: TextStyle(color: Colors.white24, letterSpacing: 10),
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _busy ? null : _verifyTelegramCode,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Verify & continue'),
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() {
              _step = AuthViewStep.form;
              _tgLoginId = '';
              _tgCodeController.clear();
              _errorMessage = '';
            }),
            icon: const Icon(CupertinoIcons.arrow_left, size: 16),
            label: const Text('Start over'),
          ),
        ),
      ],
    );
  }

  Widget _buildCompleteProfileView(AuthService auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy ? null : _useAnotherAccount,
            icon: const Icon(CupertinoIcons.arrow_left, size: 16),
            label: const Text('Use another account'),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: RuchaTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RuchaTheme.border),
            gradient: LinearGradient(
              colors: [
                RuchaTheme.surface,
                RuchaTheme.accentGreen.withValues(alpha: 0.07)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ONE LAST STEP',
                style: TextStyle(
                  color: RuchaTheme.accentGold,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Finish your athlete profile',
                style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
              SizedBox(height: 5),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _label('Athlete name'),
        const SizedBox(height: 6),
        TextField(
          controller: _displayNameController,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: const InputDecoration(
            prefixIcon: Icon(CupertinoIcons.person, size: 18),
            hintText: 'Your full name',
          ),
        ),
        const SizedBox(height: 14),
        _usernameLabel(),
        const SizedBox(height: 6),
        _usernameField(hint: 'letters, numbers and _ (3-20)'),
        const SizedBox(height: 14),
        _label('Phone number (optional)'),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: const InputDecoration(
            prefixIcon: Icon(CupertinoIcons.phone, size: 18),
            hintText: '+251 9… or 09…',
          ),
        ),
        const SizedBox(height: 14),
        _label('Password'),
        const SizedBox(height: 6),
        _passwordField(hint: 'at least ${auth.minPassword} characters'),
        const SizedBox(height: 16),
        _consentRow(auth),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: _busy ? null : _submitCompleteProfile,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Complete account & start running'),
        ),
      ],
    );
  }

  Widget _telegramSection(AuthService auth) {
    // While we're checking the server, show a loading button
    if (auth.isCheckingServer) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 16,
          height: 16,
          child:
              CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
        ),
        label: const Text('Connecting to server…'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2AABEE).withOpacity(0.5),
          foregroundColor: Colors.white70,
        ),
      );
    }

    if (auth.telegramAvailable) {
      return ElevatedButton.icon(
        onPressed: _busy ? null : _startTelegram,
        icon: const Icon(CupertinoIcons.paperplane_fill, size: 18),
        label: Text(
          auth.config.telegramBot.isNotEmpty
              ? 'Continue with Telegram'
              : 'Continue with Telegram',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2AABEE),
          foregroundColor: Colors.white,
        ),
      );
    }

    // Server is reachable but Telegram not configured — show a subtle note,
    // no "Configure" button (that belongs in Settings, not the sign-in screen)
    if (auth.serverOnline) {
      return const SizedBox.shrink(); // Telegram not set up — just hide it
    }

    // Server not reachable — show a minimal retry row
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(CupertinoIcons.wifi_slash,
            size: 14, color: RuchaTheme.textSecondary),
        const SizedBox(width: 6),
        Text(
          'Can\'t reach server',
          style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: () => auth.fetchConfig(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            minimumSize: Size.zero,
          ),
          child: const Text('Retry', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _usernameLabel() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _label('Username'),
        if (_usernameStatus.isNotEmpty)
          Text(
            _usernameReason,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _usernameStatus == 'available'
                  ? RuchaTheme.accentGreen
                  : (_usernameStatus == 'checking'
                      ? RuchaTheme.textSecondary
                      : RuchaTheme.accentRed),
            ),
          ),
      ],
    );
  }

  Widget _usernameField({required String hint}) {
    return TextField(
      controller: _usernameController,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: const Icon(CupertinoIcons.at, size: 18),
        hintText: hint,
        suffixIcon: _usernameStatus == 'available'
            ? const Icon(CupertinoIcons.checkmark_alt,
                color: RuchaTheme.accentGreen, size: 18)
            : (_usernameStatus == 'taken'
                ? const Icon(CupertinoIcons.xmark,
                    color: RuchaTheme.accentRed, size: 16)
                : null),
      ),
    );
  }

  Widget _passwordField({required String hint}) {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: const Icon(CupertinoIcons.lock, size: 18),
        hintText: hint,
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
            color: RuchaTheme.textSecondary,
            size: 19,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: RuchaTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _consentRow(AuthService auth) {
    final version = auth.config.privacyVersion;
    return InkWell(
      onTap: () => setState(() => _acceptConsent = !_acceptConsent),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: _acceptConsent,
            onChanged: (value) =>
                setState(() => _acceptConsent = value ?? false),
            activeColor: RuchaTheme.accentGreen,
            checkColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: const BorderSide(color: RuchaTheme.border, width: 1.5),
          ),
          Expanded(
            child: Text(
              'I accept the RUCHA Privacy Policy and Terms of Use (v$version).',
              style: const TextStyle(
                  color: RuchaTheme.textSecondary, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: RuchaTheme.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: RuchaTheme.textSecondary.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const Expanded(child: Divider(color: RuchaTheme.border)),
      ],
    );
  }
}

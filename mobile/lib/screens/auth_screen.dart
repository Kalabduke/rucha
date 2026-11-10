import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

enum AuthViewStep {
  form,
  telegramCode,
  completeProfile,
}

class AuthScreen extends StatefulWidget {
  final bool initialIsLogin;

  const AuthScreen({super.key, this.initialIsLogin = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isLogin;
  AuthViewStep _currentStep = AuthViewStep.form;

  // Form Controllers
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _tgCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _acceptPrivacy = false;
  bool _acceptTerms = false;
  String _errorMessage = '';
  bool _isBusy = false;

  // Telegram verification state
  String _tgLoginId = '';
  String _tgBotName = '';
  String _tgLink = '';

  // Username validation state
  Timer? _debounceTimer;
  String _usernameStatus = ''; // 'checking', 'available', 'taken', ''
  String _usernameReason = '';

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _tgCodeController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    if (_isLogin) return;
    _debounceTimer?.cancel();
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

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final auth = Provider.of<AuthService>(context, listen: false);
      final res = await auth.checkUsername(text);
      if (!mounted) return;
      setState(() {
        if (res['available'] == true) {
          _usernameStatus = 'available';
          _usernameReason = 'Available';
        } else {
          _usernameStatus = 'taken';
          _usernameReason = res['reason']?.toString() ?? 'Unavailable';
        }
      });
    });
  }

  Future<void> _handleTelegramStart() async {
    setState(() {
      _isBusy = true;
      _errorMessage = '';
    });
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final res = await auth.telegramStart();
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _tgLoginId = res.loginId;
        _tgBotName = res.bot;
        _tgLink = res.link;
        _currentStep = AuthViewStep.telegramCode;
      });

      // Try launching Telegram app or web deep link
      if (res.link.isNotEmpty) {
        final uri = Uri.parse(res.link);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _handleTelegramVerify() async {
    final code = _tgCodeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit code sent by your Telegram bot.');
      return;
    }
    setState(() {
      _isBusy = true;
      _errorMessage = '';
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final res = await auth.telegramVerify(_tgLoginId, code);

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (res.success && res.user != null) {
      if (!res.user!.profileComplete) {
        setState(() {
          _currentStep = AuthViewStep.completeProfile;
          _displayNameController.text = res.user!.displayName;
          _usernameController.text = res.user!.username;
        });
      } else {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() => _errorMessage = res.error ?? 'Verification failed.');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isBusy = true;
      _errorMessage = '';
    });
    final auth = Provider.of<AuthService>(context, listen: false);
    // In mobile/desktop clients, triggers standard OAuth or test credential
    final res = await auth.googleSignIn('demo_google_token');
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (res.success && res.user != null) {
      if (!res.user!.profileComplete) {
        setState(() => _currentStep = AuthViewStep.completeProfile);
      } else {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() => _errorMessage = res.error ?? 'Google sign-in could not be completed.');
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isBusy = true;
      _errorMessage = '';
    });
    final auth = Provider.of<AuthService>(context, listen: false);
    final res = await auth.appleSignIn('demo_apple_token');
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (res.success && res.user != null) {
      if (!res.user!.profileComplete) {
        setState(() => _currentStep = AuthViewStep.completeProfile);
      } else {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() => _errorMessage = res.error ?? 'Apple sign-in could not be completed.');
    }
  }

  Future<void> _handleSubmitForm() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final displayName = _displayNameController.text.trim();

    if (username.isEmpty) {
      setState(() => _errorMessage = 'Please enter a username.');
      return;
    }
    if (password.length < 5) {
      setState(() => _errorMessage = 'Password must be at least 5 characters.');
      return;
    }

    if (!_isLogin && (!_acceptPrivacy || !_acceptTerms)) {
      setState(() => _errorMessage = 'Please accept the Privacy Policy and Terms of Use.');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = '';
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final res = _isLogin
        ? await auth.login(username, password)
        : await auth.register(
            username,
            password,
            displayName,
            acceptPrivacy: _acceptPrivacy,
            acceptTerms: _acceptTerms,
          );

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (res.success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _errorMessage = res.error ?? 'Authentication failed.');
    }
  }

  Future<void> _handleCompleteProfile() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final displayName = _displayNameController.text.trim();

    if (username.isEmpty) {
      setState(() => _errorMessage = 'Please choose a permanent username.');
      return;
    }
    if (password.length < 5) {
      setState(() => _errorMessage = 'Please choose a password of at least 5 characters.');
      return;
    }
    if (!_acceptPrivacy || !_acceptTerms) {
      setState(() => _errorMessage = 'Please accept the Privacy Policy and Terms of Use to finish.');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = '';
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final res = await auth.completeProfile(
      username,
      password,
      displayName,
      acceptPrivacy: _acceptPrivacy,
      acceptTerms: _acceptTerms,
    );

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (res.success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _errorMessage = res.error ?? 'Could not complete profile.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RuchaTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.xmark, color: RuchaTheme.textSecondary),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text('RUCHA · ሩጫ', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage.isNotEmpty) _buildErrorBanner(),

              if (_currentStep == AuthViewStep.telegramCode)
                _buildTelegramCodeView()
              else if (_currentStep == AuthViewStep.completeProfile)
                _buildCompleteProfileView()
              else
                _buildMainAuthView(),
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
        color: const Color(0xFF2C1618),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RuchaTheme.accentRed.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: RuchaTheme.accentRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.clear, size: 14, color: Colors.white70),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _errorMessage = ''),
          ),
        ],
      ),
    );
  }

  Widget _buildMainAuthView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode Selector (Sign In vs Create Account)
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
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isLogin = false;
                    _errorMessage = '';
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_isLogin ? RuchaTheme.accentGreen : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Create account',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: !_isLogin ? Colors.white : RuchaTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isLogin = true;
                    _errorMessage = '';
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isLogin ? RuchaTheme.accentGreen : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Sign in',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _isLogin ? Colors.white : RuchaTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Social Sign In Section
        // 1. Telegram Button (Recommended)
        ElevatedButton(
          onPressed: _isBusy ? null : _handleTelegramStart,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2AABEE),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.paperplane_fill, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Continue with Telegram',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Recommended',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 2. Google & Apple Row
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isBusy ? null : _handleGoogleSignIn,
                style: OutlinedButton.styleFrom(
                  backgroundColor: RuchaTheme.surface,
                  side: const BorderSide(color: RuchaTheme.border),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.globe, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Google',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _isBusy ? null : _handleAppleSignIn,
                style: OutlinedButton.styleFrom(
                  backgroundColor: RuchaTheme.surface,
                  side: const BorderSide(color: RuchaTheme.border),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apple, size: 20, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Apple ID',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Divider
        Row(
          children: [
            const Expanded(child: Divider(color: RuchaTheme.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                _isLogin ? 'OR WITH USERNAME' : 'OR CREATE WITH USERNAME',
                style: const TextStyle(
                  color: RuchaTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const Expanded(child: Divider(color: RuchaTheme.border)),
          ],
        ),

        const SizedBox(height: 20),

        // Display Name (only in Sign Up)
        if (!_isLogin) ...[
          const Text('Display Name', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _displayNameController,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'e.g. Derartu Tulu',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              filled: true,
              fillColor: RuchaTheme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Username Field
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Username', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            if (!_isLogin && _usernameStatus.isNotEmpty)
              Text(
                _usernameReason,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _usernameStatus == 'available'
                      ? RuchaTheme.accentGreen
                      : (_usernameStatus == 'checking' ? RuchaTheme.accentGold : RuchaTheme.accentRed),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _usernameController,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'letters, numbers and _ (3-20)',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
            filled: true,
            fillColor: RuchaTheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
          ),
        ),

        const SizedBox(height: 14),

        // Password Field
        const Text('Password', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'at least 5 characters',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
            filled: true,
            fillColor: RuchaTheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                color: RuchaTheme.textSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),

        // Consent Checkboxes (Sign Up Only)
        if (!_isLogin) ...[
          const SizedBox(height: 18),
          _buildConsentCheckbox(
            value: _acceptPrivacy,
            onChanged: (v) => setState(() => _acceptPrivacy = v ?? false),
            label: 'I accept the Privacy Policy (v2026-11-07)',
          ),
          const SizedBox(height: 8),
          _buildConsentCheckbox(
            value: _acceptTerms,
            onChanged: (v) => setState(() => _acceptTerms = v ?? false),
            label: 'I accept the Terms of Use (v2026-11-07)',
          ),
        ],

        const SizedBox(height: 24),

        // Submit Button
        ElevatedButton(
          onPressed: _isBusy ? null : _handleSubmitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: RuchaTheme.accentGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _isBusy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isLogin ? CupertinoIcons.arrow_right_circle_fill : CupertinoIcons.checkmark_alt_circle_fill, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _isLogin ? 'Sign in to RUCHA' : 'Create Account',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 16),
        Center(
          child: Text(
            'GPS data is recorded locally on your device.\nNo email required.',
            textAlign: TextAlign.center,
            style: TextStyle(color: RuchaTheme.textSecondary.withOpacity(0.7), fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildConsentCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: RuchaTheme.accentGreen,
            checkColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: const BorderSide(color: RuchaTheme.border, width: 1.5),
          ),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelegramCodeView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back Button
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _currentStep = AuthViewStep.form;
              _errorMessage = '';
            }),
            icon: const Icon(CupertinoIcons.arrow_left, size: 16, color: RuchaTheme.accentGreen),
            label: const Text('Back', style: TextStyle(color: RuchaTheme.accentGreen, fontWeight: FontWeight.w600)),
          ),
        ),

        const SizedBox(height: 10),

        // Card Head
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
                  color: const Color(0xFF2AABEE).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'TELEGRAM SIGN-IN',
                  style: TextStyle(
                    color: Color(0xFF2AABEE),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Check Telegram', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 6),
              const Text(
                'The code is sent securely in your Telegram chat, so RUCHA never needs your phone number or email.',
                style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 18),

              // Steps
              _buildTelegramStepItem('1', 'Open the RUCHA bot in Telegram and press Start.'),
              const SizedBox(height: 10),
              _buildTelegramStepItem('2', 'The bot will send you a 6-digit verification code.'),
              const SizedBox(height: 10),
              _buildTelegramStepItem('3', 'Type that 6-digit code in the field below.'),

              const SizedBox(height: 20),

              // Open Bot Link Button
              if (_tgLink.isNotEmpty)
                ElevatedButton(
                  onPressed: () async {
                    final uri = Uri.parse(_tgLink);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2AABEE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.paperplane_fill, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Open @${_tgBotName.isNotEmpty ? _tgBotName : "bot"}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Code Input Field
        const Text(
          '6-DIGIT VERIFICATION CODE',
          style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
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
          decoration: InputDecoration(
            counterText: '',
            hintText: '······',
            hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 10),
            filled: true,
            fillColor: RuchaTheme.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: RuchaTheme.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2AABEE))),
          ),
        ),

        const SizedBox(height: 18),

        // Verify Button
        ElevatedButton(
          onPressed: _isBusy ? null : _handleTelegramVerify,
          style: ElevatedButton.styleFrom(
            backgroundColor: RuchaTheme.accentGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isBusy
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Verify Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildTelegramStepItem(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: RuchaTheme.border,
            shape: BoxShape.circle,
          ),
          child: Text(number, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35)),
        ),
      ],
    );
  }

  Widget _buildCompleteProfileView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  color: RuchaTheme.accentGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'WELCOME ATHLETE',
                  style: TextStyle(color: RuchaTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Complete Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 6),
              const Text(
                'Choose your permanent RUCHA username and password. Your activities and trophies will be tied to this username.',
                style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Display Name
        const Text('Display Name', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _displayNameController,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: RuchaTheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
          ),
        ),

        const SizedBox(height: 14),

        // Permanent Username
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Unique Username', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            if (_usernameStatus.isNotEmpty)
              Text(
                _usernameReason,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _usernameStatus == 'available' ? RuchaTheme.accentGreen : RuchaTheme.accentRed,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _usernameController,
          autocorrect: false,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: RuchaTheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
          ),
        ),

        const SizedBox(height: 14),

        // Password
        const Text('Password', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'at least 5 characters',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
            filled: true,
            fillColor: RuchaTheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash, color: RuchaTheme.textSecondary, size: 20),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Consents
        _buildConsentCheckbox(
          value: _acceptPrivacy,
          onChanged: (v) => setState(() => _acceptPrivacy = v ?? false),
          label: 'I accept the Privacy Policy (v2026-11-07)',
        ),
        const SizedBox(height: 8),
        _buildConsentCheckbox(
          value: _acceptTerms,
          onChanged: (v) => setState(() => _acceptTerms = v ?? false),
          label: 'I accept the Terms of Use (v2026-11-07)',
        ),

        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _isBusy ? null : _handleCompleteProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: RuchaTheme.accentGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isBusy
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Finish Creating Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

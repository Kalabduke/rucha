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
  final _phoneController = TextEditingController();
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
    _phoneController.dispose();
    _tgCodeController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    if (_isLogin && _currentStep != AuthViewStep.completeProfile) return;
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

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
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

      // Launch Telegram app or deep link
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
      // If user profile is not complete, take them to the onboarding screen
      if (!res.user!.profileComplete) {
        setState(() {
          _currentStep = AuthViewStep.completeProfile;
          _displayNameController.text = res.user!.displayName == 'New Athlete' ? '' : res.user!.displayName;
          _usernameController.text = '';
          _passwordController.text = '';
          _phoneController.text = res.user!.phoneNumber;
        });
      } else {
        // Already an existing verified user with complete profile
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() => _errorMessage = res.error ?? 'Verification failed.');
    }
  }

  // Handle Username & Password Login for returning users
  Future<void> _handleUsernameLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty) {
      setState(() => _errorMessage = 'Please enter your username.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password.');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = '';
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final res = await auth.login(username, password);

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (res.success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _errorMessage = res.error ?? 'Wrong username or password.');
    }
  }

  // Handle Complete Profile ("when they get inside ask them to set a name username and password")
  Future<void> _handleCompleteProfile() async {
    final displayName = _displayNameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final phone = _phoneController.text.trim();

    if (displayName.isEmpty) {
      setState(() => _errorMessage = 'Please enter your athlete full name.');
      return;
    }
    if (username.isEmpty) {
      setState(() => _errorMessage = 'Please choose a unique @username.');
      return;
    }
    if (username.length < 3 || username.length > 20) {
      setState(() => _errorMessage = 'Username must be between 3 and 20 characters.');
      return;
    }
    if (_usernameStatus == 'taken') {
      setState(() => _errorMessage = 'This username is already taken. Choose another.');
      return;
    }
    if (password.length < 5) {
      setState(() => _errorMessage = 'Password must be at least 5 characters.');
      return;
    }
    if (!_acceptPrivacy || !_acceptTerms) {
      setState(() => _errorMessage = 'Please accept the Privacy Policy and Terms of Use.');
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
      phoneNumber: phone,
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: RuchaTheme.accentGreen,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(CupertinoIcons.flame_fill, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text(
              'RUCHA · ሩጫ',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 16),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
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
        // Mode Selector: [ Create Account (Telegram) ] vs [ Sign In (Username/Password) ]
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

        const SizedBox(height: 22),

        // If 'Create Account': TELEGRAM ONLY FLOW
        if (!_isLogin)
          _buildTelegramOnlyCreateAccountView()
        // If 'Sign In': USERNAME & PASSWORD LOGIN FLOW
        else
          _buildUsernameSignInView(),
      ],
    );
  }

  /// 1. CREATE ACCOUNT: TELEGRAM ONLY
  Widget _buildTelegramOnlyCreateAccountView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: RuchaTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RuchaTheme.border),
            gradient: LinearGradient(
              colors: [
                RuchaTheme.surface,
                const Color(0xFF2AABEE).withOpacity(0.07),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2AABEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(CupertinoIcons.paperplane_fill, size: 22, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Telegram Fast Sign-Up',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        Text(
                          'የቴሌግራም ፈጣን ምዝገባ',
                          style: TextStyle(fontSize: 11, color: RuchaTheme.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Create your RUCHA athlete account securely via Telegram. Once inside, you will set your permanent name, @username, and password.',
                style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 18),
              _buildFeatureCheck('Instant bot verification — no email or spam'),
              const SizedBox(height: 8),
              _buildFeatureCheck('Set your unique @username inside for friends to find you'),
              const SizedBox(height: 8),
              _buildFeatureCheck('Log in anytime afterwards with your username and password'),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Primary Telegram Sign-Up Button
        ElevatedButton(
          onPressed: _isBusy ? null : _handleTelegramStart,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2AABEE),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
          child: _isBusy
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.paperplane_fill, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Create Account with Telegram',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 20),

        Center(
          child: TextButton(
            onPressed: () => setState(() => _isLogin = true),
            child: const Text(
              'Already registered? Sign in with your username →',
              style: TextStyle(color: RuchaTheme.accentGreen, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  /// 2. SIGN IN: USERNAME & PASSWORD LOGIN
  Widget _buildUsernameSignInView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Username',
          style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _usernameController,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: const Icon(CupertinoIcons.at, size: 18, color: RuchaTheme.textSecondary),
            hintText: 'Enter your username',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
            filled: true,
            fillColor: RuchaTheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.accentGreen)),
          ),
        ),

        const SizedBox(height: 16),

        const Text(
          'Password',
          style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: const Icon(CupertinoIcons.lock, size: 18, color: RuchaTheme.textSecondary),
            hintText: 'Enter your password',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
            filled: true,
            fillColor: RuchaTheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.accentGreen)),
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

        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _isBusy ? null : _handleUsernameLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: RuchaTheme.accentGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _isBusy
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.arrow_right_circle_fill, size: 20),
                    SizedBox(width: 8),
                    Text('Sign In to RUCHA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
        ),

        const SizedBox(height: 24),

        // Alternative: Sign in with Telegram
        Row(
          children: [
            const Expanded(child: Divider(color: RuchaTheme.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'OR SIGN IN WITH TELEGRAM',
                style: TextStyle(
                  color: RuchaTheme.textSecondary.withOpacity(0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const Expanded(child: Divider(color: RuchaTheme.border)),
          ],
        ),

        const SizedBox(height: 18),

        OutlinedButton.icon(
          onPressed: _isBusy ? null : _handleTelegramStart,
          icon: const Icon(CupertinoIcons.paperplane_fill, size: 18, color: Color(0xFF2AABEE)),
          label: const Text(
            'Sign In with Telegram Bot',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: RuchaTheme.surface,
            side: const BorderSide(color: RuchaTheme.border),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  /// 3. TELEGRAM 6-DIGIT CODE STEP
  Widget _buildTelegramCodeView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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

        const SizedBox(height: 8),

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
                  'TELEGRAM VERIFICATION',
                  style: TextStyle(color: Color(0xFF2AABEE), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Check Telegram Bot', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 6),
              const Text(
                'Open the RUCHA bot on Telegram and tap Start to get your 6-digit code.',
                style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),

              if (_tgLink.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(_tgLink);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(CupertinoIcons.paperplane_fill, size: 18),
                  label: Text('Open @${_tgBotName.isNotEmpty ? _tgBotName : "rucha_bot"} in Telegram'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2AABEE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        const Text(
          'ENTER 6-DIGIT CODE',
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

        ElevatedButton(
          onPressed: _isBusy ? null : _handleTelegramVerify,
          style: ElevatedButton.styleFrom(
            backgroundColor: RuchaTheme.accentGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isBusy
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Verify & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),

        const SizedBox(height: 14),
        Center(
          child: Text(
            'Tip: Use code 123456 for offline test verification',
            style: TextStyle(color: RuchaTheme.textSecondary.withOpacity(0.6), fontSize: 11),
          ),
        ),
      ],
    );
  }

  /// 4. ONBOARDING: COMPLETE PROFILE (SET NAME, USERNAME, PASSWORD)
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: RuchaTheme.accentGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'STEP 2: ATHLETE PROFILE',
                  style: TextStyle(color: RuchaTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Set Up Your Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 6),
              const Text(
                'Set your name, username, and password. Friends will search and challenge you with your username, and you will use it to log in afterwards.',
                style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 1. Full Display Name
        const Text('Athlete Name', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _displayNameController,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'e.g. Kenenisa Bekele',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
            filled: true,
            fillColor: RuchaTheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
          ),
        ),

        const SizedBox(height: 14),

        // 2. Unique Username
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Unique Username (@username)', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
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
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: const Icon(CupertinoIcons.at, size: 18, color: RuchaTheme.textSecondary),
            hintText: 'letters, numbers and _ (3-20)',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
            helperText: 'Friends will search for you using this username',
            helperStyle: TextStyle(color: RuchaTheme.accentGold.withOpacity(0.9), fontSize: 11),
            filled: true,
            fillColor: RuchaTheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
          ),
        ),

        const SizedBox(height: 14),

        // 3. Ethiopian Phone Number
        const Text('Phone Number', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🇪🇹', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text('+251', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  SizedBox(width: 8),
                  Text('|', style: TextStyle(color: RuchaTheme.border)),
                ],
              ),
            ),
            hintText: '09... or 07...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
            filled: true,
            fillColor: RuchaTheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
          ),
        ),

        const SizedBox(height: 14),

        // 4. Password
        const Text('Set Password (for future logins)', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: const Icon(CupertinoIcons.lock, size: 18, color: RuchaTheme.textSecondary),
            hintText: 'at least 5 characters',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
            helperText: 'Use this username and password to log in directly afterwards',
            helperStyle: TextStyle(color: RuchaTheme.textSecondary.withOpacity(0.8), fontSize: 11),
            filled: true,
            fillColor: RuchaTheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
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
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isBusy
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Complete Account & Start Running', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _buildFeatureCheck(String text) {
    return Row(
      children: [
        const Icon(CupertinoIcons.checkmark_alt_circle_fill, size: 16, color: RuchaTheme.accentGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
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
}

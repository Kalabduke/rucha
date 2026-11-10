import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/challenge.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../core/theme.dart';

class ChallengesScreen extends StatefulWidget {
  final VoidCallback? onStartRecording;

  const ChallengesScreen({super.key, this.onStartRecording});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  List<Challenge> _challenges = [];
  bool _isLoading = true;
  final Set<String> _joinedIds = {};

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
        for (final c in _challenges) {
          if (c.isJoined) _joinedIds.add(c.id);
        }
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
        kind: 'vertical',
        mode: 'open',
        targetElev: 1000.0,
        prizeBirr: 5000,
        isJoined: true,
      ),
      Challenge(
        id: 'c2',
        title: 'Bishoftu Crater Lakes 10K',
        description: 'Loop the rim of Lake Bishoftu in under 48 minutes.',
        kind: 'distance_time',
        mode: 'open',
        targetKm: 10.0,
        targetTime: 2880,
        prizeBirr: 3500,
      ),
      Challenge(
        id: 'c3',
        title: 'Meskel Square 5K Sprint Duel',
        description: 'Head-to-head sprint duel on the Meskel Square circuit. Winner takes 2,000 Birr.',
        kind: 'head_to_head',
        mode: 'head_to_head',
        targetKm: 5.0,
        prizeBirr: 2000,
        opponentName: 'kenenisa',
      ),
      Challenge(
        id: 'c4',
        title: 'Adwa 30-Day Consistency Streak',
        description: 'Record an activity every day for 30 consecutive days across Ethiopian highlands.',
        kind: 'streak',
        mode: 'open',
        prizeBirr: 10000,
      ),
    ];
  }

  void _showCreateChallengeSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final opponentCtrl = TextEditingController();
    final kmCtrl = TextEditingController(text: '5.0');
    final prizeCtrl = TextEditingController(text: '2000');

    String selectedKind = 'route';
    String selectedMode = 'open';
    String selectedVis = 'everyone';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: RuchaTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: RuchaTheme.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: RuchaTheme.accentGreen,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(CupertinoIcons.flag_fill, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create a Challenge',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'ውድድር ወይም የሁለትዮሽ ፉክክር ፍጠር',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: RuchaTheme.accentGold,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: RuchaTheme.textSecondary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Challenge Title
                    const Text('Challenge Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RuchaTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. Meskel to Entoto Hill Sprint',
                        hintStyle: TextStyle(color: RuchaTheme.textSecondary.withOpacity(0.5)),
                        filled: true,
                        fillColor: RuchaTheme.surface2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Challenge Kind
                    const Text('Challenge Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RuchaTheme.textSecondary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedKind,
                      dropdownColor: RuchaTheme.surface2,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: RuchaTheme.surface2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'route', child: Text('Point-to-Point Trail Race')),
                        DropdownMenuItem(value: 'distance_time', child: Text('Fastest Time over Distance (Time Trial)')),
                        DropdownMenuItem(value: 'vertical', child: Text('Vertical Kilometer (Elevation Gain)')),
                        DropdownMenuItem(value: 'head_to_head', child: Text('1 vs 1 Athlete Duel')),
                        DropdownMenuItem(value: 'streak', child: Text('Consistency Streak (Daily Runs)')),
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly Mileage Target')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
                            selectedKind = val;
                            if (val == 'head_to_head') selectedMode = 'head_to_head';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Format: Open vs Duel
                    const Text('Format', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RuchaTheme.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setSheetState(() => selectedMode = 'open'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedMode == 'open' ? RuchaTheme.accentGreen.withOpacity(0.2) : RuchaTheme.surface2,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: selectedMode == 'open' ? RuchaTheme.accentGreen : RuchaTheme.border),
                              ),
                              child: Center(
                                child: Text(
                                  'Open Challenge',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selectedMode == 'open' ? Colors.white : RuchaTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => setSheetState(() => selectedMode = 'head_to_head'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedMode == 'head_to_head' ? RuchaTheme.accentCoral.withOpacity(0.2) : RuchaTheme.surface2,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: selectedMode == 'head_to_head' ? RuchaTheme.accentCoral : RuchaTheme.border),
                              ),
                              child: Center(
                                child: Text(
                                  '1 vs 1 Duel (ፉክክር)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selectedMode == 'head_to_head' ? Colors.white : RuchaTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Duel opponent field
                    if (selectedMode == 'head_to_head') ...[
                      const Text('Opponent Username (@username)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RuchaTheme.accentCoral)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: opponentCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'e.g. haile_g or kenenisa_b',
                          hintStyle: TextStyle(color: RuchaTheme.textSecondary.withOpacity(0.5)),
                          prefixIcon: const Icon(CupertinoIcons.at, size: 16, color: RuchaTheme.accentCoral),
                          filled: true,
                          fillColor: RuchaTheme.surface2,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.accentCoral)),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Target Distance & Prize
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Target Distance (km)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RuchaTheme.textSecondary)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: kmCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: '5.0',
                                  filled: true,
                                  fillColor: RuchaTheme.surface2,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Prize Pool (ETB Birr)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RuchaTheme.accentGold)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: prizeCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: RuchaTheme.accentGold, fontSize: 14, fontWeight: FontWeight.w800),
                                decoration: InputDecoration(
                                  hintText: '2500',
                                  prefixText: 'Br ',
                                  prefixStyle: const TextStyle(color: RuchaTheme.accentGold, fontWeight: FontWeight.w800),
                                  filled: true,
                                  fillColor: RuchaTheme.surface2,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.accentGold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Description / Rules
                    const Text('Rules & Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RuchaTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Start at Meskel Square, finish at Entoto Park gate. Telebirr payout upon verification.',
                        hintStyle: TextStyle(color: RuchaTheme.textSecondary.withOpacity(0.5)),
                        filled: true,
                        fillColor: RuchaTheme.surface2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: RuchaTheme.border)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final title = titleCtrl.text.trim();
                              if (title.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please give your challenge a name')),
                                );
                                return;
                              }

                              final opponent = opponentCtrl.text.trim().replaceAll('@', '');
                              if (selectedMode == 'head_to_head' && opponent.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter your opponent\'s username')),
                                );
                                return;
                              }

                              setSheetState(() => isSubmitting = true);

                              final auth = context.read<AuthService>();
                              final currentUser = auth.currentUser;
                              final prize = int.tryParse(prizeCtrl.text) ?? 0;
                              final km = double.tryParse(kmCtrl.text) ?? 5.0;

                              final newChallenge = Challenge(
                                id: 'ch_${DateTime.now().millisecondsSinceEpoch}',
                                title: title,
                                description: descCtrl.text.trim().isNotEmpty
                                    ? descCtrl.text.trim()
                                    : 'A thrilling running challenge created by ${currentUser?.displayName ?? "an athlete"}.',
                                kind: selectedKind,
                                mode: selectedMode,
                                targetKm: km,
                                prizeBirr: prize,
                                visibility: selectedVis,
                                opponentName: selectedMode == 'head_to_head' ? opponent : null,
                                createdBy: currentUser?.displayName ?? 'Athlete',
                                isJoined: true,
                              );

                              // Post to backend
                              final nav = Navigator.of(ctx);
                              final messenger = ScaffoldMessenger.of(context);
                              final api = context.read<ApiService>();
                              await api.createChallenge(newChallenge.toJson());

                              if (mounted) {
                                setState(() {
                                  _challenges.insert(0, newChallenge);
                                  _joinedIds.add(newChallenge.id);
                                });
                                nav.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    backgroundColor: RuchaTheme.accentGreen,
                                    content: Text('Challenge "$title" created successfully!'),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RuchaTheme.accentGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSubmitting
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : const Text(
                              'Create Challenge (ውድድር ፍጠር)',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPrize = _challenges.fold<int>(0, (sum, c) => sum + c.prizeBirr);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ethiopian Flag Strip
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
                Text('Challenges & Duels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(width: 8),
                Text('ውድድሮች', style: TextStyle(fontSize: 12, color: RuchaTheme.accentGold, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.plus_circle_fill, color: RuchaTheme.accentGreen, size: 28),
            tooltip: 'Create Challenge',
            onPressed: _showCreateChallengeSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : RefreshIndicator(
              onRefresh: _loadChallenges,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header Hero Banner with Ethiopian Prize Pool
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: RuchaTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: RuchaTheme.border),
                      gradient: LinearGradient(
                        colors: [
                          RuchaTheme.surface,
                          RuchaTheme.accentGreen.withOpacity(0.08),
                          RuchaTheme.accentGold.withOpacity(0.08),
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
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: RuchaTheme.accentGold.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(CupertinoIcons.money_dollar_circle_fill, color: RuchaTheme.accentGold, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('TOTAL PRIZE POOL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: RuchaTheme.accentGold, letterSpacing: 0.8)),
                                    Text('Br $totalPrize ETB', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                                  ],
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: _showCreateChallengeSheet,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Create', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RuchaTheme.accentGreen,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${_challenges.length} challenges active · Open to everyone, friends & 1v1 duels with cash prizes via Telebirr.',
                          style: const TextStyle(fontSize: 12, color: RuchaTheme.textSecondary, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Challenge List
                  ..._challenges.map((c) {
                    final isJoined = _joinedIds.contains(c.id);
                    final isDuel = c.mode == 'head_to_head' || c.kind == 'head_to_head';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: RuchaTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDuel ? RuchaTheme.accentCoral.withOpacity(0.4) : RuchaTheme.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDuel ? RuchaTheme.accentCoral.withOpacity(0.2) : RuchaTheme.surface2,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isDuel ? CupertinoIcons.bolt_fill : CupertinoIcons.flag_fill,
                                          size: 11,
                                          color: isDuel ? RuchaTheme.accentCoral : RuchaTheme.accentGreen,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isDuel ? '1 VS 1 DUEL' : c.kind.toUpperCase().replaceAll('_', ' '),
                                          style: TextStyle(
                                            color: isDuel ? RuchaTheme.accentCoral : RuchaTheme.accentGreen,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (c.opponentName != null && c.opponentName!.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text('vs @${c.opponentName}', style: const TextStyle(fontSize: 11, color: RuchaTheme.accentGold, fontWeight: FontWeight.w700)),
                                  ],
                                ],
                              ),
                              if (c.prizeBirr > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: RuchaTheme.accentGold.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: RuchaTheme.accentGold.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.stars, color: RuchaTheme.accentGold, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Br ${c.prizeBirr}',
                                        style: const TextStyle(
                                          color: RuchaTheme.accentGold,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            c.title,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c.description,
                            style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 12),

                          // Target metrics badges
                          Row(
                            children: [
                              if (c.targetKm != null && c.targetKm! > 0)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: RuchaTheme.surface2,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('${c.targetKm} km', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                                ),
                              if (c.targetElev != null && c.targetElev! > 0)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: RuchaTheme.surface2,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('+${c.targetElev!.round()}m elevation', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Buttons: Join & Race
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    if (isJoined) {
                                      _joinedIds.remove(c.id);
                                    } else {
                                      _joinedIds.add(c.id);
                                    }
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isJoined ? 'Left "${c.title}"' : 'Joined "${c.title}"!'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  isJoined ? Icons.check : Icons.group_add,
                                  size: 14,
                                  color: isJoined ? RuchaTheme.accentGreen : Colors.white,
                                ),
                                label: Text(
                                  isJoined ? 'Joined' : 'Join Challenge',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isJoined ? RuchaTheme.accentGreen : Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  side: BorderSide(
                                    color: isJoined ? RuchaTheme.accentGreen : RuchaTheme.border,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  if (widget.onStartRecording != null) {
                                    widget.onStartRecording!();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Starting "${c.title}" live tracker!')),
                                    );
                                  }
                                },
                                icon: const Icon(CupertinoIcons.play_arrow_solid, size: 12),
                                label: const Text('Race', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDuel ? RuchaTheme.accentCoral : RuchaTheme.accentGreen,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

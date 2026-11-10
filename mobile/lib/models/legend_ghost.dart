import 'package:flutter/material.dart';

class LegendGhost {
  final String id;
  final String name;
  final String amharicName;
  final String title;
  final String note;
  final double targetPaceSec; // Target benchmark pace (seconds per km)
  final Color accentColor;
  final String icon;

  const LegendGhost({
    required this.id,
    required this.name,
    required this.amharicName,
    required this.title,
    required this.note,
    required this.targetPaceSec,
    required this.accentColor,
    this.icon = '🇪🇹',
  });

  String get targetPaceFormatted {
    final m = (targetPaceSec / 60).floor();
    final s = (targetPaceSec % 60).round();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}/km';
  }

  /// Calculates dynamic note based on athlete's current pace
  String getPaceDeltaNote(double currentPaceSec) {
    if (currentPaceSec <= 0) return 'Matching $name pace';
    final delta = targetPaceSec - currentPaceSec; // positive = faster than legend
    final deltaAbs = delta.abs().round();
    final secStr = '$deltaAbs sec';

    if (delta > 3) {
      return '⚔️ +$secStr faster than $name ($targetPaceFormatted)';
    } else if (delta < -3) {
      return '🏃 $secStr behind $name ($targetPaceFormatted)';
    } else {
      return '🔥 Running shoulder-to-shoulder with $name ($amharicName)';
    }
  }

  static const List<LegendGhost> all = [
    LegendGhost(
      id: 'abebe',
      name: 'Abebe Bikila',
      amharicName: 'አበበ ቢቂላ',
      title: 'Rome 1960 Marathon Legend',
      note: 'Barefoot Olympic Gold (2:15:16)',
      targetPaceSec: 192.0, // 3:12/km
      accentColor: Color(0xFFE5A93C),
      icon: '👑',
    ),
    LegendGhost(
      id: 'haile',
      name: 'Haile Gebrselassie',
      amharicName: 'ኃይሌ ገብረሥላሴ',
      title: 'The Emperor (5K/10K/Marathon)',
      note: '27 World Records · 1998 Zurich Split',
      targetPaceSec: 210.0, // 3:30/km
      accentColor: Color(0xFF0E8A6A),
      icon: '⚡',
    ),
    LegendGhost(
      id: 'kenenisa',
      name: 'Kenenisa Bekele',
      amharicName: 'ቀነኒሳ በቀለ',
      title: 'Cross-Country & Track King',
      note: 'Bekoji Legend · Berlin 2:01:41',
      targetPaceSec: 195.0, // 3:15/km
      accentColor: Color(0xFF2AABEE),
      icon: '🦅',
    ),
    LegendGhost(
      id: 'derartu',
      name: 'Derartu Tulu',
      amharicName: 'ደራርቱ ቱሉ',
      title: 'Barcelona 1992 Olympic Pioneer',
      note: 'First Black African Woman Olympic Champion',
      targetPaceSec: 205.0, // 3:25/km
      accentColor: Color(0xFFE0533C),
      icon: '🌟',
    ),
    LegendGhost(
      id: 'tirunesh',
      name: 'Tirunesh Dibaba',
      amharicName: 'ጥሩነሽ ዲባባ',
      title: 'Baby-Faced Destroyer',
      note: 'Beijing Double Gold 5K & 10K',
      targetPaceSec: 200.0, // 3:20/km
      accentColor: Color(0xFFFF7A42),
      icon: '🔥',
    ),
    LegendGhost(
      id: 'cadet',
      name: 'Ethio Club Cadet',
      amharicName: 'የክለብ አባል',
      title: 'High Altitude Squad Pacer',
      note: 'Addis Altitude Club Standard',
      targetPaceSec: 285.0, // 4:45/km
      accentColor: Color(0xFF5FD6A8),
      icon: '🎯',
    ),
  ];
}

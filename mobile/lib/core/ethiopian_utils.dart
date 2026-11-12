/// Ethiopian-specific utilities: calendar conversion and Geez numerals.
library;

// ─── Geez Numeral Conversion ──────────────────────────────────────────────────
//
// Converts a Western integer to Ethiopic (Geez) numeral string.
// The Geez system is not purely positional; it uses unit glyphs (1–9),
// tens glyphs (10–90), hundreds (100, 1000) and combines them without zero.

const _geezOnes = ['', '፩', '፪', '፫', '፬', '፭', '፮', '፯', '፰', '፱'];
const _geezTens = ['', '፲', '፳', '፴', '፵', '፶', '፷', '፸', '፹', '፺'];

/// Converts [n] to a Geez numeral string. Numbers < 1 or > 9999 fall back
/// to the standard Western representation.
String toGeez(int n) {
  if (n <= 0 || n > 9999) return n.toString();

  final thousands = n ~/ 1000;
  final hundreds = (n % 1000) ~/ 100;
  final tens = (n % 100) ~/ 10;
  final ones = n % 10;

  final buf = StringBuffer();
  if (thousands > 0) {
    buf.write(_geezOnes[thousands]);
    buf.write('፲፻'); // 1000 marker
  }
  if (hundreds > 0) {
    buf.write(_geezOnes[hundreds]);
    buf.write('፻'); // 100 marker
  }
  buf.write(_geezTens[tens]);
  buf.write(_geezOnes[ones]);
  return buf.toString();
}

/// Converts all digit sequences in [s] to Geez numerals when [enabled] is true.
String applyGeez(String s, {required bool enabled}) {
  if (!enabled) return s;
  return s.replaceAllMapped(RegExp(r'\d+'), (m) {
    final n = int.tryParse(m[0]!);
    if (n == null) return m[0]!;
    return toGeez(n);
  });
}

// ─── Ethiopian Calendar Conversion ───────────────────────────────────────────
//
// The Ethiopian calendar (Ge'ez calendar) has 12 months of 30 days each
// plus a 13th short month (Pagume) of 5 or 6 days.
// The Ethiopian year is ~7-8 years behind the Gregorian year.
//
// Conversion algorithm based on the standard Julian Day Number method.

const _ethMonthNames = [
  'መስከረም', // Meskerem  — Sep/Oct
  'ጥቅምት',  // Tikimt    — Oct/Nov
  'ሕዳር',   // Hidar     — Nov/Dec
  'ታህሳስ',  // Tahsas    — Dec/Jan
  'ጥር',    // Tir       — Jan/Feb
  'የካቲት',  // Yekatit   — Feb/Mar
  'መጋቢት',  // Megabit   — Mar/Apr
  'ሚያዝያ',  // Miyaziya  — Apr/May
  'ግንቦት',  // Ginbot    — May/Jun
  'ሰኔ',    // Sene      — Jun/Jul
  'ሐምሌ',   // Hamle     — Jul/Aug
  'ነሐሴ',   // Nehase    — Aug/Sep
  'ጳጉሜ',   // Pagume    — Sep
];

const _ethMonthNamesEn = [
  'Meskerem', 'Tikimt', 'Hidar', 'Tahsas', 'Tir', 'Yekatit',
  'Megabit', 'Miyaziya', 'Ginbot', 'Sene', 'Hamle', 'Nehase', 'Pagume',
];

class EthiopianDate {
  final int year;
  final int month; // 1–13
  final int day;   // 1–30 (1–5/6 for Pagume)

  const EthiopianDate(this.year, this.month, this.day);

  String monthName({bool amharic = true}) =>
      amharic ? _ethMonthNames[month - 1] : _ethMonthNamesEn[month - 1];

  /// Short formatted string e.g. "፲፭/መስከረም/፳፻፲፮" (Geez) or "15 Meskerem 2016" (English)
  String format({bool geez = false, bool amharic = true}) {
    if (geez) {
      return '${toGeez(day)} ${monthName(amharic: true)} ${toGeez(year)}';
    }
    return '$day ${monthName(amharic: amharic)} $year';
  }
}

/// Converts a Gregorian [DateTime] to an [EthiopianDate].
EthiopianDate toEthiopian(DateTime gregorian) {
  // Julian Day Number for the Gregorian date
  final a = (14 - gregorian.month) ~/ 12;
  final y = gregorian.year + 4800 - a;
  final m = gregorian.month + 12 * a - 3;
  final jdn = gregorian.day +
      (153 * m + 2) ~/ 5 +
      365 * y +
      y ~/ 4 -
      y ~/ 100 +
      y ~/ 400 -
      32045;

  // Convert JDN to Ethiopian
  final r = (jdn - 1723856) % 1461;
  final n = r % 365 + 365 * (r ~/ 1460);
  final i = n ~/ 30;
  final day = n % 30 + 1;
  final month = i % 13 + 1;
  final year = 4 * ((jdn - 1723856) ~/ 1461) + (r ~/ 365) - (r ~/ 1460);

  return EthiopianDate(year, month, day);
}

/// Formats a Gregorian [DateTime] as a human-readable Ethiopian date string.
/// When [useEthiopian] is false it falls back to Gregorian formatting.
/// When [useGeez] is true numbers are rendered in Geez script.
String formatEthiopianDate(
  DateTime date, {
  bool useEthiopian = true,
  bool useGeez = false,
  bool amharic = true,
}) {
  if (!useEthiopian) {
    return '${date.day}/${date.month}/${date.year}';
  }
  return toEthiopian(date).format(geez: useGeez, amharic: amharic);
}

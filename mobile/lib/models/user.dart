class User {
  final String id;
  final String username;
  final String displayName;
  final String phoneNumber;
  final String city;
  final String createdAt;
  final bool profileComplete;
  final bool hasPassword;
  final List<String> providers;
  final String privacyVersion;
  final String termsVersion;

  const User({
    required this.id,
    required this.username,
    required this.displayName,
    this.phoneNumber = '',
    this.city = 'Addis Ababa',
    required this.createdAt,
    this.profileComplete = true,
    this.hasPassword = true,
    this.providers = const [],
    this.privacyVersion = '',
    this.termsVersion = '',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    var rawProviders = json['providers'];
    List<String> provList = [];
    if (rawProviders is List) {
      provList = rawProviders.map((e) => e.toString()).toList();
    } else if (json['provider'] != null) {
      provList = [json['provider'].toString()];
    }

    return User(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? json['username']?.toString() ?? 'Athlete',
      phoneNumber: json['phone']?.toString() ?? json['phoneNumber']?.toString() ?? '',
      city: json['city']?.toString() ?? 'Addis Ababa',
      createdAt: json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      profileComplete: json['profileComplete'] != false,
      hasPassword: json['hasPassword'] == true,
      providers: provList,
      privacyVersion: json['privacyVersion']?.toString() ?? '',
      termsVersion: json['termsVersion']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    'phone': phoneNumber,
    'city': city,
    'createdAt': createdAt,
    'profileComplete': profileComplete,
    'hasPassword': hasPassword,
    'providers': providers,
    'privacyVersion': privacyVersion,
    'termsVersion': termsVersion,
  };
}

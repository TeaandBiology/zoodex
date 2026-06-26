/// The local user profile. There are no accounts yet, so this lives on the
/// device with placeholder defaults; editing (display name, @username, and an
/// avatar chosen from a preset set) comes later.
class Profile {
  /// Permanent local id (UUID v4), assigned once on first launch. This is the
  /// seed for a future anonymous/linked backend account (no login required —
  /// see DESIGN §8), so it must never change once set.
  final String userId;

  final String displayName;
  final String username; // stored without the leading '@'
  final DateTime joinedAt;

  /// Which preset avatar image to show. For now only 'default' exists, which
  /// maps to images/default.png; a picker will be added later.
  final String avatarId;

  /// The user's chosen "local zoo" (a zoo id they've visited), or '' if unset.
  final String localZooId;

  const Profile({
    this.userId = '',
    required this.displayName,
    required this.username,
    required this.joinedAt,
    this.avatarId = 'default',
    this.localZooId = '',
  });

  factory Profile.initial(DateTime now, {String userId = ''}) => Profile(
        userId: userId,
        displayName: 'ZooDex Explorer',
        username: 'explorer',
        joinedAt: now,
        avatarId: 'default',
      );

  /// Asset path for the chosen avatar. (Only the placeholder exists for now.)
  String get avatarAsset => 'images/default_profile.png';

  Profile copyWith({
    String? userId,
    String? displayName,
    String? username,
    String? avatarId,
    String? localZooId,
  }) =>
      Profile(
        userId: userId ?? this.userId,
        displayName: displayName ?? this.displayName,
        username: username ?? this.username,
        joinedAt: joinedAt,
        avatarId: avatarId ?? this.avatarId,
        localZooId: localZooId ?? this.localZooId,
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'displayName': displayName,
        'username': username,
        'joinedAt': joinedAt.toIso8601String(),
        'avatarId': avatarId,
        'localZooId': localZooId,
      };

  static Profile fromMap(Map<dynamic, dynamic> m) {
    final ts = m['joinedAt'];
    return Profile(
      userId: (m['userId'] ?? '').toString(),
      displayName: (m['displayName'] ?? 'ZooDex Explorer').toString(),
      username: (m['username'] ?? 'explorer').toString(),
      joinedAt:
          ts is String ? (DateTime.tryParse(ts) ?? DateTime.now()) : DateTime.now(),
      avatarId: (m['avatarId'] ?? 'default').toString(),
      localZooId: (m['localZooId'] ?? '').toString(),
    );
  }
}

/// A person the signed-in user has blocked.
class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.name,
    this.username,
    this.avatarUrl,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: json['id']?.toString() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      username: _nonEmpty(json['username']?.toString().replaceFirst('@', '')),
      avatarUrl: _nonEmpty(json['avatarUrl']),
    );
  }

  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;

  String get displayName {
    if (name.isNotEmpty) return name;
    if (username != null) return '@$username';
    return 'Hamme user';
  }
}

/// `GET /profiles/me/blocked`: blocked people, plus how many anonymous voters
/// are blocked (they have no identity to list).
class BlockedUsersResult {
  const BlockedUsersResult({
    this.users = const <BlockedUser>[],
    this.anonymousBlockedCount = 0,
  });

  factory BlockedUsersResult.fromJson(Map<String, dynamic> json) {
    final users = json['users'] as List<dynamic>? ?? const <dynamic>[];
    return BlockedUsersResult(
      users:
          users
              .whereType<Map<String, dynamic>>()
              .map(BlockedUser.fromJson)
              .where((user) => user.id.isNotEmpty)
              .toList(),
      anonymousBlockedCount:
          (json['anonymousBlockedCount'] as num?)?.toInt() ?? 0,
    );
  }

  final List<BlockedUser> users;
  final int anonymousBlockedCount;

  bool get isEmpty => users.isEmpty && anonymousBlockedCount <= 0;
}

String? _nonEmpty(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

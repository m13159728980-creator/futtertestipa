class GroupMember {
  const GroupMember({
    required this.userId,
    required this.role,
    required this.account,
    required this.displayName,
    this.avatarIndex = 0,
  });

  final String userId;
  final String role;
  final String account;
  final String displayName;
  final int avatarIndex;

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['userId'].toString(),
      role: json['role'] as String? ?? 'member',
      account: json['account'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarIndex: json['avatarIndex'] as int? ?? 0,
    );
  }
}

class Group {
  const Group({
    required this.id,
    required this.groupCode,
    required this.name,
    required this.ownerId,
    required this.members,
    this.burnEnabled = false,
  });

  final String id;
  final String groupCode;
  final String name;
  final String ownerId;
  final bool burnEnabled;
  final List<GroupMember> members;

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'].toString(),
      groupCode: json['groupCode'] as String? ?? '',
      name: json['name'] as String? ?? '',
      ownerId: json['ownerId'].toString(),
      burnEnabled: json['burnEnabled'] == true,
      members: [
        for (final item in (json['members'] as List? ?? const []))
          if (item is Map<String, dynamic>) GroupMember.fromJson(item),
      ],
    );
  }
}

class UserModel {
  final String id;
  final String username;
  final String zone;
  final String wareHouse;
  final String firstName;
  final bool? isBlocked;
  final String type;
  final String lastName;
  UserModel({
    required this.id,
    required this.username,
    required this.zone,
    required this.wareHouse,
    required this.firstName,
    required this.type,
    required this.lastName,
    this.isBlocked,
  });
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] ?? json; // Handle nested or flat structure

    return UserModel(
      // ✅ Handle id as int or String
      id: user['id']?.toString() ?? '',

      // ✅ username may not exist → build from firstname + lastname
      username: user['username'] as String? ??
          '${user['firstname'] ?? ''} ${user['lastname'] ?? ''}'.trim(),

      zone: user['zone'] as String? ?? '',

      // ✅ Map 'warehouse' (API) to 'warHouse' (model)
      wareHouse: user['warehouse'] as String? ?? user['warHouse'] as String? ?? '',

      firstName: user['firstname'] as String? ?? '',
      type: user['type'] as String? ?? '',
      lastName: user['lastname'] as String? ?? '',
      isBlocked: user['isBlocked'] as bool?,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'zone': zone,
      'warHouse': wareHouse,
      'isBlocked': isBlocked,
    };
  }
}

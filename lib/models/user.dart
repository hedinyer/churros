class AppUser {
  final int id;
  final String userId;
  final String? accessKey;
  final int? sucursalId;

  AppUser({
    required this.id,
    required this.userId,
    this.accessKey,
    this.sucursalId,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      accessKey: json['access_key'] as String?,
      sucursalId: json['sucursal'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'access_key': accessKey,
      'sucursal': sucursalId,
    };
  }
}

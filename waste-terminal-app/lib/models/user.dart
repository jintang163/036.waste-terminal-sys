class User {
  final int? id;
  final String? username;
  final String? password;
  final String? realName;
  final String? phone;
  final String? email;
  final String? avatar;
  final int? deptId;
  final String? role;
  final int? status;
  final DateTime? lastLoginTime;
  final String? lastLoginIp;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? deleted;

  User({
    this.id,
    this.username,
    this.password,
    this.realName,
    this.phone,
    this.email,
    this.avatar,
    this.deptId,
    this.role,
    this.status,
    this.lastLoginTime,
    this.lastLoginIp,
    this.createTime,
    this.updateTime,
    this.deleted,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int?,
      username: json['username'] as String?,
      password: json['password'] as String?,
      realName: json['realName'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      avatar: json['avatar'] as String?,
      deptId: json['deptId'] as int?,
      role: json['role'] as String?,
      status: json['status'] as int?,
      lastLoginTime: json['lastLoginTime'] != null
          ? DateTime.tryParse(json['lastLoginTime'] as String)
          : null,
      lastLoginIp: json['lastLoginIp'] as String?,
      createTime: json['createTime'] != null
          ? DateTime.tryParse(json['createTime'] as String)
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.tryParse(json['updateTime'] as String)
          : null,
      deleted: json['deleted'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'realName': realName,
      'phone': phone,
      'email': email,
      'avatar': avatar,
      'deptId': deptId,
      'role': role,
      'status': status,
      'lastLoginTime': lastLoginTime?.toIso8601String(),
      'lastLoginIp': lastLoginIp,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'deleted': deleted,
    };
  }

  User copyWith({
    int? id,
    String? username,
    String? password,
    String? realName,
    String? phone,
    String? email,
    String? avatar,
    int? deptId,
    String? role,
    int? status,
    DateTime? lastLoginTime,
    String? lastLoginIp,
    DateTime? createTime,
    DateTime? updateTime,
    int? deleted,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      realName: realName ?? this.realName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      deptId: deptId ?? this.deptId,
      role: role ?? this.role,
      status: status ?? this.status,
      lastLoginTime: lastLoginTime ?? this.lastLoginTime,
      lastLoginIp: lastLoginIp ?? this.lastLoginIp,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      deleted: deleted ?? this.deleted,
    );
  }
}

enum UserRole {
  guest,
  client,
  admin,
}

class User {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final String address;
  final UserRole role;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.address,
    required this.role,
  });
}



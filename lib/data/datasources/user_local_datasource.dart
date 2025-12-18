import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class UserLocalDataSource {
  final DatabaseHelper dbHelper;

  UserLocalDataSource(this.dbHelper);

  Future<int> insertUser({
    required String fullName,
    required String phone,
    required String address,
    required String email,
    required String password,
    required String role,
  }) async {
    final db = await dbHelper.database;
    return db.insert(
      'Users',
      {
        'FullName': fullName,
        'Phone': phone,
        'Address': address,
        'Email': email,
        'PasswordHash': password,
        'Role': role,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await dbHelper.database;
    final res = await db.query(
      'Users',
      where: 'Email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return res.isEmpty ? null : res.first;
  }

  Future<Map<String, dynamic>?> getUserByEmailAndPassword(
    String email,
    String password,
  ) async {
    final db = await dbHelper.database;
    final res = await db.query(
      'Users',
      where: 'Email = ? AND PasswordHash = ?',
      whereArgs: [email, password],
      limit: 1,
    );
    return res.isEmpty ? null : res.first;
  }

  Future<void> deleteUser(int id) async {
    final db = await dbHelper.database;
    await db.delete('Users', where: 'Id = ?', whereArgs: [id]);
  }

  Future<void> updateUser({
    required int id,
    required String fullName,
    required String phone,
    required String address,
    required String email,
    String? password, // если null, пароль не изменять
  }) async {
    final db = await dbHelper.database;
    final updateData = {
      'FullName': fullName,
      'Phone': phone,
      'Address': address,
      'Email': email,
    };
    if (password != null && password.isNotEmpty) {
      updateData['PasswordHash'] = password;
    }
    await db.update('Users', updateData, where: 'Id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await dbHelper.database;
    final res = await db.query(
      'Users',
      where: 'Id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return res.isEmpty ? null : res.first;
  }
}




import 'package:flutter/foundation.dart';

import '../../domain/entities/user.dart';
import '../../data/datasources/user_local_datasource.dart';
import '../providers/sale_provider.dart';

class AuthProvider with ChangeNotifier {
  final UserLocalDataSource userLocalDataSource;

  AuthProvider(this.userLocalDataSource);

  UserRole _role = UserRole.guest;
  String? _fullName;
  String? _phone;
  String? _address;
  int? _userId;
  String? _email;

  UserRole get role => _role;
  String? get fullName => _fullName;
  String? get phone => _phone;
  String? get address => _address;
  int? get userId => _userId;
  String? get email => _email;

  bool get isGuest => _role == UserRole.guest;
  bool get isClient => _role == UserRole.client;
  bool get isAdmin => _role == UserRole.admin;

  String get displayName {
    if (_fullName == null || _fullName!.trim().isEmpty || isGuest) {
      return 'Гость';
    }
    final parts = _fullName!.trim().split(RegExp(r'\s+'));
    final surname = parts.isNotEmpty ? parts[0] : '';
    final firstInitial =
        parts.length > 1 && parts[1].isNotEmpty ? parts[1][0].toUpperCase() : '';
    if (surname.isEmpty) return 'Гость';
    return '$surname${firstInitial.isNotEmpty ? ' $firstInitial.' : ''}';
  }

  /// Выполняет вход пользователя в систему
  /// Поддерживает специальный вход для администратора и обычную аутентификацию пользователей
  ///
  /// @param email - email пользователя
  /// @param password - пароль пользователя
  Future<void> login(String email, String password) async {
    // Специальный вход для администратора (без проверки в БД)
    if (email == 'admin@admin.ru' && password == 'admin') {
      _role = UserRole.admin;
      _fullName = 'Админ';
      _email = email;
      _userId = 0; // Фиксированный ID для админа
      _phone = null;
      _address = null;
      notifyListeners();
      return;
    }

    // Обычная аутентификация через базу данных
    final userMap =
        await userLocalDataSource.getUserByEmailAndPassword(email, password);
    if (userMap == null) {
      throw Exception('Неверный email или пароль');
    }

    // Устанавливаем данные пользователя из базы данных
    _role = _mapRole(userMap['Role'] as String?);
    _fullName = userMap['FullName'] as String?;
    _phone = userMap['Phone'] as String?;
    _address = userMap['Address'] as String?;
    _userId = userMap['Id'] as int?;
    _email = userMap['Email'] as String?;

    // Уведомляем слушателей об изменении состояния аутентификации
    notifyListeners();
  }

  /// Регистрирует нового клиента в системе
  /// Создает учетную запись пользователя и автоматически входит в систему
  ///
  /// @param fullName - полное имя пользователя
  /// @param phone - номер телефона
  /// @param address - адрес доставки
  /// @param email - email (уникальный)
  /// @param password - пароль
  Future<void> registerClient({
    required String fullName,
    required String phone,
    required String address,
    required String email,
    required String password,
  }) async {
    // Проверяем, что email не зарезервирован для администратора
    if (email == 'admin@admin.ru') {
      throw Exception('Этот email зарезервирован для администратора');
    }

    // Проверяем, что пользователь с таким email еще не зарегистрирован
    final existing = await userLocalDataSource.getUserByEmail(email);
    if (existing != null) {
      throw Exception('Пользователь с таким email уже зарегистрирован');
    }

    // Создаем нового пользователя в базе данных
    await userLocalDataSource.insertUser(
      fullName: fullName,
      phone: phone,
      address: address,
      email: email,
      password: password,
      role: 'client', // Роль клиента
    );

    // Автоматически входим в систему от имени нового пользователя
    _role = UserRole.client;
    _fullName = fullName;
    _phone = phone;
    _address = address;

    // Получаем ID только что созданного пользователя из базы данных
    final user = await userLocalDataSource.getUserByEmail(email);
    _userId = user?['Id'] as int?;
    _email = email;

    // Уведомляем слушателей об успешной регистрации и входе
    notifyListeners();
  }

  UserRole _mapRole(String? raw) {
    switch (raw) {
      case 'admin':
        return UserRole.admin;
      case 'client':
      case 'User':
      default:
        return UserRole.client;
    }
  }

  Future<void> deleteAccount() async {
    if (isClient && _userId != null) {
      await userLocalDataSource.deleteUser(_userId!);
      logout();
    } else {
      throw Exception('Аккаунт удалить нельзя');
    }
  }

  Future<void> updateAccount({
    required String fullName,
    required String phone,
    required String address,
    required String email,
    String? password,
  }) async {
    if (!isClient || _userId == null) {
      throw Exception('Изменение аккаунта не доступно');
    }
    // Проверяем, что email не занят другим пользователем
    if (email != _email) {
      final existing = await userLocalDataSource.getUserByEmail(email);
      if (existing != null && existing['Id'] != _userId) {
        throw Exception('Пользователь с таким email уже зарегистрирован');
      }
    }
    await userLocalDataSource.updateUser(
      id: _userId!,
      fullName: fullName,
      phone: phone,
      address: address,
      email: email,
      password: password,
    );
    _fullName = fullName;
    _phone = phone;
    _address = address;
    _email = email;
    notifyListeners();
  }

  void logout() {
    _role = UserRole.guest;
    _fullName = null;
    _phone = null;
    _address = null;
    _userId = null;
    _email = null;
    notifyListeners();
  }

  /// Выполняет выход из системы с очисткой корзины
  /// Гарантирует, что при следующем входе корзина будет пустой
  ///
  /// @param saleProvider - провайдер корзины для очистки
  Future<void> logoutWithCartClear(SaleProvider saleProvider) async {
    logout(); // Сбрасываем данные пользователя
    // Очищаем корзину при выходе (null для гостей)
    await saleProvider.clearCart(null);
  }

  // Метод для уведомления других провайдеров об изменении аутентификации
  // Должен вызываться после login/logout для синхронизации состояния
  void notifyAuthChanged() {
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getUserDetailsById(int userId) async {
    return await userLocalDataSource.getUserById(userId);
  }
}


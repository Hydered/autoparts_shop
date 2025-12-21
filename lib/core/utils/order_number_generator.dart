import 'dart:math';

class OrderNumberGenerator {
  static const String _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static final Random _random = Random();

  /// Генерирует уникальный номер заказа формата: AP-XXXX-XXXX
  /// где AP - префикс (Auto Parts), XXXX - случайные буквы и цифры
  static String generate() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = _generateRandomString(6);
    final timestampPart = timestamp.toString().substring(timestamp.toString().length - 4);
    
    return 'AP-$randomPart-$timestampPart';
  }

  static String _generateRandomString(int length) {
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => _chars.codeUnitAt(_random.nextInt(_chars.length)),
      ),
    );
  }
}

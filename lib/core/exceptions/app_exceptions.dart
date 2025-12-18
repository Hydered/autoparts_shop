class AppException implements Exception {
  final String message;
  AppException(this.message);
  
  @override
  String toString() => message;
}

class InsufficientStockException extends AppException {
  InsufficientStockException(String productName, int available, int requested)
      : super('Недостаточно товаров для $productName. Доступно: $available, Запрошено: $requested');
}

class AppDatabaseException extends AppException {
  AppDatabaseException(String message) : super('Ошибка базы данных: $message');
}

class NotFoundException extends AppException {
  NotFoundException(String entity) : super('$entity не найден');
}

